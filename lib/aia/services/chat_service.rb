
module AIA
  module Services
    class ChatService
      def initialize(client:, directives_processor:, logger:)
        @client = client
        @directives_processor = directives_processor
        @logger = logger
        @spinner = TTY::Spinner.new(":spinner :title", format: :classic)
        @spinner.update(title: "composing response ... ")
      end

      def process_chat(prompt)
        prompt = preprocess_prompt(prompt)
        if handle_directives(prompt)
          process_directive_output
        else
          process_regular_prompt(prompt)
        end
      end

      private

      def preprocess_prompt(prompt)
        prompt = render_erb(prompt) if AIA.config.erb?
        prompt = render_env(prompt) if AIA.config.shell?
        prompt
      end

      def process_directive_output
        return if @directive_output.empty?
        prompt = preprocess_prompt(@directive_output)
        result = get_and_display_result(prompt)
        log_and_speak(prompt, result)
      end

      def process_regular_prompt(prompt)
        prompt = insert_terse_phrase(prompt)
        result = get_and_display_result(prompt)
        log_and_speak(prompt, result)
      end

      def get_and_display_result(prompt_text)
        @spinner.auto_spin if AIA.config.verbose?
        result = @client.chat(prompt_text)
        @spinner.success("Done.") if AIA.config.verbose?
        display_result(result)
        result
      end

      def log_and_speak(prompt, result)
        @logger.info "Follow Up:\n#{prompt}"
        @logger.info "Response:\n#{result}"
        AIA.speak(result) if AIA.config.speak?
      end

      def handle_directives(prompt)
        signal = AIA::Prompt::DIRECTIVE_SIGNAL
        return false unless prompt.start_with?(signal)

        parts = prompt[signal.size..].split(' ')
        directive = parts.shift
        parameters = parts.join(' ')
        AIA.config.directives << [directive, parameters]

        @directive_output = @directives_processor.execute_my_directives
        true
      end

      def insert_terse_phrase(string)
        AIA.config.terse? ? "Be terse in your response. #{string}" : string
      end
    end
  end
end
