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
    def handle(context)
      robot  = context.robot
      prompt = context.prompt
      return false unless robot.is_a?(RobotLab::Network)

      mention_tokens = prompt.scan(/@(\w+)/i).flatten
      return false if mention_tokens.empty?

      all_robots = robot.robots.values
      matched = mention_tokens.filter_map do |token|
        all_robots.find { |r| r.name.downcase == token.downcase }
      end.uniq(&:name)

      return false if matched.empty?

      report_unknown_mentions(mention_tokens, all_robots)
      run_mentioned_robots(matched, prompt)
      true
    end

    private

    def report_unknown_mentions(mention_tokens, all_robots)
      known_names = all_robots.map { |r| r.name.downcase }
      unknown = mention_tokens.reject { |t| known_names.include?(t.downcase) }
      return unless unknown.any?

      available = all_robots.map(&:name).join(', ')
      unknown.each do |name|
        @ui_presenter.display_info("Unknown robot: @#{name}  (available: #{available})")
      end
    end

    def run_mentioned_robots(robots, prompt)
      parts = []

      robots.each do |bot|
        begin
          result, streamed_content, elapsed = @streaming_runner.run(
            bot, prompt,
            header: "\nAI (#{bot.name}):\n   ",
            spinner_message: "#{bot.name} processing..."
          )
        rescue StandardError => e
          @ui_presenter.display_info("Error from #{bot.name}: #{e.class}: #{e.message}")
          next
        end

        content = streamed_content || extract_content(result)

        @tracker.record_turn(
          model: bot.model || 'unknown',
          input: prompt,
          result: result,
          elapsed: elapsed
        )

        if streamed_content
          puts
          @ui_presenter.display_info("(#{format_duration(elapsed)})")
        else
          model_label = bot.model || 'unknown'
          header = "**#{bot.name}** [#{model_label}] (#{format_duration(elapsed)}):"
          parts << "#{header}\n#{content}"
        end

        output_to_file(content)
        display_metrics(result, elapsed: elapsed)
        speak(content)
      end

      unless parts.empty?
        @ui_presenter.display_ai_response(parts.join("\n\n"))
      end

      @ui_presenter.display_separator
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

      command = AIA.config.audio.speak_command || 'say'
      system(command, content.to_s)
    rescue StandardError => e
      warn "Warning: Speech failed: #{e.message}"
    end
  end
end
