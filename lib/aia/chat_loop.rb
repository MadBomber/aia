# frozen_string_literal: true

# lib/aia/chat_loop.rb
#
# Thin interactive chat shell for AIA v2.
# Uses robot.run(input) for AI interaction — robot maintains
# conversation history internally via its persistent RubyLLM::Chat.

require "reline"
require "pm"

module AIA
  class ChatLoop
    def initialize(robot, ui_presenter, directive_processor, rule_router)
      @robot               = robot
      @ui_presenter        = ui_presenter
      @directive_processor = directive_processor
      @rule_router         = rule_router
    end

    # Start the interactive chat session
    def start(skip_context_files: false)
      setup_session
      process_initial_context(skip_context_files)
      run_loop
    ensure
      @ui_presenter.display_chat_end
    end

    private

    def setup_session
      initialize_ui
      setup_signals
      Reline::HISTORY.clear
    end

    def initialize_ui
      puts "\nEntering interactive chat mode..."
      @ui_presenter.display_chat_header
    end

    def setup_signals
      Signal.trap("INT") { exit }
    end

    def process_initial_context(skip_context_files)
      return if skip_context_files || !AIA.config.context_files || AIA.config.context_files.empty?

      context = AIA.config.context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return if context.empty?

      result, streamed_content = run_with_streaming(context)
      content = streamed_content || extract_content(result)

      if streamed_content
        puts  # newline after streamed content
      else
        @ui_presenter.display_ai_response(content)
      end
      output_to_file(content)
      speak(content)
      @ui_presenter.display_separator
    end

    def run_loop
      loop do
        follow_up_prompt = @ui_presenter.ask_question

        break if follow_up_prompt.nil? || follow_up_prompt.strip.downcase == "exit" || follow_up_prompt.strip.empty?

        log_user_input(follow_up_prompt)

        if @directive_processor.directive?(follow_up_prompt)
          follow_up_prompt = process_directive(follow_up_prompt)
          next if follow_up_prompt.nil?
        end

        begin
          processed_prompt = PM.parse_string(follow_up_prompt).to_s
        rescue StandardError => e
          @ui_presenter.display_info("Error: #{e.class}: #{e.message}")
          next
        end

        # Rules may modify config before each turn
        @rule_router&.evaluate_turn(AIA.config, processed_prompt)

        begin
          result, streamed_content = run_with_streaming(processed_prompt)
        rescue StandardError => e
          @ui_presenter.display_info("Error communicating with AI: #{e.class}: #{e.message}")
          next
        end

        content = streamed_content || extract_content(result)

        if streamed_content
          puts  # newline after streamed content
        else
          @ui_presenter.display_ai_response(content)
        end
        output_to_file(content)
        display_metrics(result)
        speak(content)
        @ui_presenter.display_separator
      end
    end

    def process_directive(follow_up_prompt)
      directive_output = @directive_processor.process(follow_up_prompt, nil)

      if follow_up_prompt.strip.start_with?("/clear", "/checkpoint", "/restore", "/review", "/context")
        @ui_presenter.display_info(directive_output) unless directive_output.nil? || directive_output.strip.empty?
        return nil
      end

      return nil if directive_output.nil? || directive_output.strip.empty?

      handle_successful_directive(follow_up_prompt, directive_output)
    end

    def handle_successful_directive(follow_up_prompt, directive_output)
      puts "\n#{directive_output}\n"
      "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
    end

    # Run robot with streaming: spinner shows until first chunk arrives,
    # then spinner stops and chunks are printed directly.
    # Returns [result, streamed_content] where streamed_content is the
    # concatenated text if streaming occurred, or nil if it didn't.
    def run_with_streaming(prompt)
      spinner = TTY::Spinner.new("[:spinner] Processing...", format: :bouncing_ball)
      spinner.auto_spin
      streamed = []
      header_printed = false

      result = @robot.run(prompt, mcp: :inherit, tools: :inherit) do |chunk|
        text = chunk.respond_to?(:content) ? chunk.content.to_s : chunk.to_s
        next if text.empty?

        unless header_printed
          spinner.stop
          print "\nAI:\n   "
          header_printed = true
        end

        streamed << text
        $stdout.print(text)
      end

      spinner.stop unless header_printed

      content = streamed.empty? ? nil : streamed.join
      [result, content]
    end

    # Extract text content from a RobotResult or string
    def extract_content(result)
      if result.respond_to?(:reply)
        result.reply
      elsif result.respond_to?(:last_text_content)
        result.last_text_content
      elsif result.respond_to?(:content)
        result.content
      else
        result.to_s
      end
    end

    # Display token metrics if enabled
    def display_metrics(result)
      return unless AIA.config.flags.tokens

      if result.respond_to?(:output) && result.output.any?
        last_msg = result.output.last
        if last_msg.respond_to?(:input_tokens)
          metrics = {
            model_id: result.respond_to?(:robot_name) ? result.robot_name : "unknown",
            input_tokens: last_msg.input_tokens,
            output_tokens: last_msg.output_tokens
          }
          @ui_presenter.display_token_metrics(metrics)
        end
      end
    end

    # Write content to output file
    def output_to_file(content)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, 'a') do |file|
        file.puts "\nAI: #{content}"
      end
    end

    # Log user input to output file
    def log_user_input(input)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, "a") do |file|
        file.puts "\nYou: #{input}"
      end
    end

    # Speak the content if speak mode is enabled
    def speak(content)
      return unless AIA.speak?

      begin
        command = AIA.config.audio.speak_command || 'say'
        system(command, content.to_s)
      rescue StandardError => e
        warn "Warning: Speech failed: #{e.message}"
      end
    end
  end
end
