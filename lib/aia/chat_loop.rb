# lib/aia/chat_loop.rb
# frozen_string_literal: true

require "reline"
require "pm"

module AIA
  class ChatLoop
    def initialize(chat_processor, ui_presenter, directive_processor)
      @chat_processor     = chat_processor
      @ui_presenter       = ui_presenter
      @directive_processor = directive_processor
    end

    # Start the interactive chat session
    def start(skip_context_files: false)
      setup_session
      process_initial_context(skip_context_files)
      handle_piped_input
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

      response_data = @chat_processor.process_prompt(context)
      content = response_data.is_a?(Hash) ? response_data[:content] : response_data

      @chat_processor.output_response(content)
      @chat_processor.speak(content)
      @ui_presenter.display_separator
    end

    def handle_piped_input
      return if STDIN.tty?
      return unless File.exist?("/dev/tty") && File.readable?("/dev/tty") && File.writable?("/dev/tty")

      begin
        original_stdin = STDIN.dup
        piped_input = STDIN.read.strip
        STDIN.reopen("/dev/tty")

        return if piped_input.empty?

        processed_input = PM.parse_string(piped_input).to_s

        response_data = @chat_processor.process_prompt(processed_input)
        content = response_data.is_a?(Hash) ? response_data[:content] : response_data

        @chat_processor.output_response(content)
        @chat_processor.speak(content) if AIA.speak?
        @ui_presenter.display_separator

        STDIN.reopen(original_stdin)
      rescue Errno::ENXIO => e
        warn "Warning: Unable to handle piped input due to TTY unavailability: #{e.message}"
        return
      rescue StandardError => e
        warn "Warning: Error handling piped input: #{e.message}"
        return
      end
    end

    def run_loop
      loop do
        follow_up_prompt = @ui_presenter.ask_question

        break if follow_up_prompt.nil? || follow_up_prompt.strip.downcase == "exit" || follow_up_prompt.strip.empty?

        if AIA.config.output.file
          File.open(AIA.config.output.file, "a") do |file|
            file.puts "\nYou: #{follow_up_prompt}"
          end
        end

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

        response_data = @chat_processor.process_prompt(processed_prompt)

        if response_data.is_a?(Hash)
          content = response_data[:content]
          metrics = response_data[:metrics]
          multi_metrics = response_data[:multi_metrics]
        else
          content = response_data
          metrics = nil
          multi_metrics = nil
        end

        @ui_presenter.display_ai_response(content)

        if AIA.config.flags.tokens
          if multi_metrics
            @ui_presenter.display_multi_model_metrics(multi_metrics)
          elsif metrics
            @ui_presenter.display_token_metrics(metrics)
          end
        end

        @chat_processor.speak(content)
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

    # Parse multi-model response into per-model responses (ADR-002 revised + ADR-005)
    def parse_multi_model_response(combined_response)
      return {} if combined_response.nil? || combined_response.empty?

      responses = {}
      current_model = nil
      current_content = []

      combined_response.each_line do |line|
        if line =~ /^from:\s+(.+)$/
          if current_model
            responses[current_model] = current_content.join.strip
          end

          display_name = $1.strip
          internal_id = display_name.sub(/\s+\([^)]+\)\s*$/, '')
          internal_id = internal_id.sub(/\s+#/, '#')

          current_model = internal_id
          current_content = []
        elsif current_model
          current_content << line
        end
      end

      if current_model
        responses[current_model] = current_content.join.strip
      end

      responses
    end
  end
end
