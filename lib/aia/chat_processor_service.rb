# lib/aia/chat_processor_service.rb

module AIA
  class ChatProcessorService
    def initialize(ui_presenter, directive_processor = nil)
      @ui_presenter = ui_presenter
      @speaker = AIA.speak? ? AiClient.new(AIA.config.speech_model) : nil
      @directive_processor = directive_processor
    end


    def speak(text)
      return unless AIA.speak?

      @speaker ||= AiClient.new(AIA.config.speech_model) if AIA.config.speech_model

      if @speaker
        `#{AIA.config.speak_command} #{@speaker.speak(text).path}`
      else
        puts "Warning: Unable to speak. Speech model not configured properly."
      end
    end


    def process_prompt(prompt)
      result = nil
      @ui_presenter.with_spinner("Processing", determine_operation_type) do
        result = send_to_client(prompt)
      end

      unless result.is_a? String
        result = result.content
      end

      result
    end


    # conversation is an Array of Hashes.  Each entry is an interchange
    # with the LLM.
    def send_to_client(conversation)
      maybe_change_model

      AIA.client.chat(conversation)
    end


    def maybe_change_model
      # With multiple models, we don't need to change the model in the same way
      # The RubyLLMAdapter now handles multiple models internally
      # This method is kept for backward compatibility but may not be needed
      return if AIA.config.model.is_a?(Array)

      client_model = AIA.client.model.id  # RubyLLM::Model instance

      unless AIA.config.model.downcase.include?(client_model.downcase)
        AIA.client = AIA.client.class.new
      end
    end


    def output_response(response)
      speak(response)

      # Output to STDOUT or file based on out_file configuration
      if AIA.config.out_file.nil? || 'STDOUT' == AIA.config.out_file.upcase
        print "\nAI:\n  "
        puts response
      else
        mode = AIA.append? ? 'a' : 'w'
        File.open(AIA.config.out_file, mode) do |file|
          file.puts "\nAI: "
          # Handle multi-line responses by adding proper indentation
          response_lines = response.to_s.split("\n")
          response_lines.each do |line|
            file.puts "  #{line}"
          end
        end
      end

      if AIA.config.log_file
        File.open(AIA.config.log_file, 'a') do |f|
          f.puts "=== #{Time.now} ==="
          f.puts "Prompt: #{AIA.config.prompt_id}"
          f.puts "Response: #{response}"
          f.puts "==="
        end
      end
    end


    def process_next_prompts(response, prompt_handler)
      if @directive_processor.directive?(response)
        directive_result = @directive_processor.process(response, @history_manager.history)
        response = directive_result[:result]
        @history_manager.history = directive_result[:modified_history] if directive_result[:modified_history]
      end
    end


    def determine_operation_type
      # With multiple models, determine operation type from the first model
      # or provide a generic description
      if AIA.config.model.is_a?(Array) && AIA.config.model.size > 1
        "MULTI-MODEL PROCESSING"
      else
        mode = AIA.config.client.model.modalities
        mode.input.join(',') + " TO " + mode.output.join(',')
      end
    end
  end
end
