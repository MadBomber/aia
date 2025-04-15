# lib/aia/chat_processor_service.rb


require_relative 'shell_command_executor'

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



    def process_prompt(prompt, operation_type)
      @ui_presenter.with_spinner("Processing", operation_type) do
        send_to_client(prompt, operation_type)
      end
    end



    def send_to_client(prompt, operation_type)
      maybe_change_model

      case operation_type
      when :text_to_text
        AIA.client.chat(prompt)
      when :text_to_image
        AIA.client.chat(prompt)
      when :image_to_text
        AIA.client.chat(prompt)
      when :text_to_audio
        AIA.client.chat(prompt)
      when :audio_to_text
        if prompt.strip.end_with?('.mp3', '.wav', '.m4a', '.flac') && File.exist?(prompt.strip)
          AIA.client.transcribe(prompt.strip)
        else
          AIA.client.chat(prompt) # Fall back to regular chat
        end
      else
        AIA.client.chat(prompt)
      end
    end


    def maybe_change_model
      if AIA.client.model != AIA.config.model
        AIA.client = AIClientAdapter.new
      end
    end


    def output_response(response)
      speak(response)

      # Only output to STDOUT if we're in chat mode

      if AIA.chat? || 'STDOUT' == AIA.config.out_file.upcase
        print "\nAI:\n  "
        puts response
      else
        mode = AIA.append? ? 'a' : 'w'
        File.open(AIA.config.out_file, mode) do |file|
          file.puts response
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


    def determine_operation_type(model)
      model = model.to_s.downcase
      if model.include?('dall') || model.include?('image-generation')
        :text_to_image
      elsif model.include?('vision') || model.include?('image')
        :image_to_text
      elsif model.include?('whisper') || model.include?('audio')
        :audio_to_text
      elsif model.include?('speech') || model.include?('tts')
        :text_to_audio
      else
        :text_to_text
      end
    end
  end
end
