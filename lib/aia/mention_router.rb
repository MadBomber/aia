# frozen_string_literal: true

# lib/aia/mention_router.rb
#
# Handles @mention routing in multi-model networks.
# Scans prompts for @name tokens, matches them to robots in the
# network, and sends the prompt only to mentioned robots.

module AIA
  class MentionRouter
    include ContentExtractor
    include HandlerProtocol

    # Reserved @mention that broadcasts the message to every crew member.
    BROADCAST_TOKEN = 'crew'

    def initialize(ui_presenter:, tracker:, streaming_runner:)
      @ui_presenter = ui_presenter
      @tracker = tracker
      @streaming_runner = streaming_runner
    end

    # Scan prompt for @mentions and route to matching robots.
    # Returns true if mentions were handled, false otherwise.
    #
    # @param context [HandlerContext] — reads context.robot and context.prompt
    # @return [Boolean]
    def handle(context) # rubocop:disable Naming/PredicateMethod
      robot  = context.robot
      prompt = context.prompt
      return false unless robot.network?

      mention_tokens = prompt.scan(/@(\w+)/i).flatten
      return false if mention_tokens.empty?

      all_robots = robot.crew
      matched = resolve_mentions(mention_tokens, all_robots)

      if matched.empty?
        report_unknown_mentions(mention_tokens, all_robots)
        return true
      end

      clean_prompt = strip_addressing_prefix(prompt)

      report_unknown_mentions(mention_tokens, all_robots)
      run_mentioned_robots(matched, clean_prompt, concurrent: leading_address_only?(prompt))
      true
    end

    private

    # Remove only the leading run of @mentions (the addressing prefix), so
    # "@alice summarize this" becomes "summarize this" while @mentions inside the
    # message body — "hello @hemie have you met @joker" — are preserved as
    # content and reach the routed robots intact.
    def strip_addressing_prefix(prompt)
      prompt.sub(/\A(?:\s*@\w+)+\s*/i, '').strip
    end

    # True when every @mention is part of the leading address — i.e. nothing but
    # @mentions before the message — so it's a broadcast to its addressees and
    # runs concurrently. A @mention woven into the body makes it sequential.
    def leading_address_only?(prompt)
      !strip_addressing_prefix(prompt).match?(/@\w+/)
    end

    # Resolve @mention tokens to robots. The reserved @crew token broadcasts to
    # the entire crew; otherwise each token is matched to a robot by name.
    #
    # @return [Array<Robot>]
    def resolve_mentions(tokens, all_robots)
      return all_robots if tokens.any? { |token| token.casecmp?(BROADCAST_TOKEN) }

      tokens.filter_map { |token| all_robots.find { |r| r.name.casecmp?(token) } }.uniq(&:name)
    end

    def report_unknown_mentions(mention_tokens, all_robots)
      known_names = all_robots.map { |r| r.name.downcase }
      unknown = mention_tokens.reject { |t| t.casecmp?(BROADCAST_TOKEN) || known_names.include?(t.downcase) }
      return unless unknown.any?

      available = all_robots.map(&:name).join(', ')
      unknown.each do |name|
        @ui_presenter.display_info("Unknown robot: @#{name}  (available: #{available})")
      end
    end

    def run_mentioned_robots(robots, prompt, concurrent:)
      if robots.size == 1
        run_streamed(robots.first, prompt)
      elsif concurrent
        run_concurrently(robots, prompt)
      else
        run_sequentially(robots, prompt)
      end
      @ui_presenter.display_separator
    end

    # Robots mentioned in the body run one at a time, each streaming its reply.
    def run_sequentially(robots, prompt)
      robots.each { |bot| run_streamed(bot, prompt) }
    end

    # A single addressed robot streams its reply token-by-token.
    def run_streamed(bot, prompt)
      result, streamed_content, elapsed = @streaming_runner.run(
        bot, prompt,
        header: "\nAI (#{bot.name}):\n   ",
        spinner_message: "#{bot.name} processing..."
      )
      content = streamed_content || extract_content(result)

      if streamed_content
        puts
        @ui_presenter.display_info("(#{format_duration(elapsed)})")
      else
        @ui_presenter.display_ai_response(reply_block(bot, content, elapsed))
      end

      finalize_reply(bot, prompt, result, content, elapsed)
    rescue StandardError => e
      @ui_presenter.display_info("Error from #{bot.name}: #{e.class}: #{e.message}")
    end

    # A broadcast to multiple robots runs them concurrently — no token streaming,
    # which would interleave on one console. Each robot runs in its own thread and
    # pushes its result to a queue; the main thread renders each reply as it lands
    # (finish order), so wall-clock is the slowest robot, not the sum. Rendering
    # stays single-threaded, so display/tracking are never touched concurrently.
    def run_concurrently(robots, prompt)
      @ui_presenter.display_info("Broadcasting to #{robots.size} robots concurrently…")

      done = Queue.new
      robots.each { |bot| Thread.new { done << run_member(bot, prompt) } }
      robots.size.times { render_member(prompt, *done.pop) }
    end

    # Run one crew member to completion (off the streaming path), in a worker
    # thread. Returns [bot, result, elapsed, error] — no shared state touched.
    def run_member(bot, prompt)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result  = bot.run(prompt, mcp: :inherit, tools: :inherit)
      [bot, result, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, nil]
    rescue StandardError => e
      [bot, nil, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, e]
    end

    # Render one crew member's reply on the main thread.
    def render_member(prompt, bot, result, elapsed, error)
      if error
        @ui_presenter.display_info("Error from #{bot.name}: #{error.class}: #{error.message}")
        return
      end

      content = extract_content(result)
      @ui_presenter.display_ai_response(reply_block(bot, content, elapsed))
      finalize_reply(bot, prompt, result, content, elapsed)
    end

    def reply_block(bot, content, elapsed)
      "**#{bot.name}** [#{bot.model || 'unknown'}] (#{format_duration(elapsed)}):\n#{content}"
    end

    def finalize_reply(bot, prompt, result, content, elapsed)
      @tracker.record_turn(model: bot.model || 'unknown', input: prompt, result: result, elapsed: elapsed)
      output_to_file(content)
      display_metrics(result, elapsed: elapsed)
      speak(content)
    end

    def display_metrics(result, elapsed: nil)
      return unless AIA.config.flags.tokens

      raw = result.respond_to?(:raw) ? result.raw : nil
      return unless raw && raw.respond_to?(:input_tokens) && raw.input_tokens

      model_id = extract_model_id(raw)
      model_id ||= result.respond_to?(:robot_name) ? result.robot_name : "unknown"
      metrics = {
        model_id:      model_id,
        input_tokens:  raw.input_tokens,
        output_tokens: raw.output_tokens,
        elapsed:       elapsed
      }
      @ui_presenter.display_token_metrics(metrics)
    end

    def extract_model_id(message)
      return message.model_id if message.respond_to?(:model_id) && message.model_id
      return message.model    if message.respond_to?(:model)    && message.model
      nil
    end

    def speak(content)
      return unless AIA.speak?

      audio   = AIA.config.audio
      command = audio.speak_command || 'say'
      env     = {}
      env['SPEECH_MODEL'] = audio.speech_model if audio.speech_model

      if command == 'say'
        run_with_spinner("Speaking...") do
          if audio.voice && !audio.voice.to_s.strip.empty?
            system(env, command, '-v', audio.voice, content.to_s)
          else
            system(env, command, content.to_s)
          end
        end
      else
        require 'tempfile'
        tmpfile = Tempfile.new(['aia-tts-', '.mp3'])
        tmpfile.close
        begin
          run_with_spinner("Converting to audio...") do
            system(env, command, content.to_s, tmpfile.path)
          end
          if File.size?(tmpfile.path)
            run_with_spinner("Speaking...") do
              system('afplay', tmpfile.path)
            end
          end
        ensure
          tmpfile.unlink
        end
      end
    rescue StandardError => e
      $stderr.puts "Warning: Speech failed: #{e.message}"
    end

    def run_with_spinner(message)
      spinner = TTY::Spinner.new("[:spinner] #{message}", format: :bouncing_ball, output: $stderr)
      spinner.auto_spin
      begin
        yield
      ensure
        spinner.stop
      end
    end
  end
end
