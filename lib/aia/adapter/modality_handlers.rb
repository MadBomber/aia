# lib/aia/adapter/modality_handlers.rb
# frozen_string_literal: true

module AIA
  module Adapter
    module ModalityHandlers
      def transcribe(audio_file)
        # Use the first model for transcription
        first_model = @models.first
        @chats[first_model].ask('Transcribe this audio', with: audio_file).content
      end

      def speak(_text)
        output_file = "#{Time.now.to_i}.mp3"

        # NOTE: RubyLLM doesn't have a direct text-to-speech feature
        # This is a placeholder for a custom implementation or external service
        begin
          File.write(output_file, 'Mock TTS audio content')
          if File.exist?(output_file) && system("which #{AIA.config.audio.speak_command} > /dev/null 2>&1")
            system("#{AIA.config.audio.speak_command} #{output_file}")
          end
          "Audio generated and saved to: #{output_file}"
        rescue StandardError => e
          "Error generating audio: #{e.message}"
        end
      end

      private

      def extract_text_prompt(prompt)
        if prompt.is_a?(String)
          prompt
        elsif prompt.is_a?(Hash) && prompt[:text]
          prompt[:text]
        elsif prompt.is_a?(Hash) && prompt[:content]
          prompt[:content]
        else
          prompt.to_s
        end
      end

      #########################################
      ## text

      def text_to_text_single(prompt, model_name)
        chat_instance = @chats[model_name]
        text_prompt = extract_text_prompt(prompt)

        response = if AIA.config.context_files.empty?
                     chat_instance.ask(text_prompt)
                   else
                     chat_instance.ask(text_prompt, with: AIA.config.context_files)
                   end

        # Return the full response object to preserve token information
        response
      rescue Exception => e # rubocop:disable Lint/RescueException
        # Catch ALL exceptions including LoadError, ScriptError, etc.
        # Tool crashes should not crash AIA - log and continue gracefully
        handle_tool_crash(chat_instance, e)
      end

      #########################################
      ## Image

      def extract_image_path(prompt)
        if prompt.is_a?(String)
          match = prompt.match(%r{\b[\w/.\-_]+?\.(jpg|jpeg|png|gif|webp)\b}i)
          match ? match[0] : nil
        elsif prompt.is_a?(Hash)
          prompt[:image] || prompt[:image_path]
        end
      end

      def text_to_image_single(prompt, model_name)
        text_prompt = extract_text_prompt(prompt)
        image_name  = extract_image_path(text_prompt)

        begin
          image = RubyLLM.paint(text_prompt, size: AIA.config.image.size)
          if image_name
            image_path = image.save(image_name)
            "Image generated and saved to: #{image_path}"
          else
            "Image generated and available at: #{image.url}"
          end
        rescue StandardError => e
          "Error generating image: #{e.message}"
        end
      end

      def image_to_text_single(prompt, model_name)
        image_path  = extract_image_path(prompt)
        text_prompt = extract_text_prompt(prompt)

        if image_path && File.exist?(image_path)
          begin
            @chats[model_name].ask(text_prompt, with: image_path).content
          rescue StandardError => e
            "Error analyzing image: #{e.message}"
          end
        else
          text_to_text_single(prompt, model_name)
        end
      end

      #########################################
      ## audio

      def audio_file?(filepath)
        filepath.to_s.downcase.end_with?('.mp3', '.wav', '.m4a', '.flac')
      end

      def text_to_audio_single(prompt, model_name)
        text_prompt = extract_text_prompt(prompt)
        output_file = "#{Time.now.to_i}.mp3"

        begin
          # NOTE: RubyLLM doesn't have a direct TTS feature
          # TODO: This is a placeholder for a custom implementation
          File.write(output_file, text_prompt)
          if File.exist?(output_file) && system("which #{AIA.config.audio.speak_command} > /dev/null 2>&1")
            system("#{AIA.config.audio.speak_command} #{output_file}")
          end
          "Audio generated and saved to: #{output_file}"
        rescue StandardError => e
          "Error generating audio: #{e.message}"
        end
      end

      def audio_to_text_single(prompt, model_name)
        text_prompt = extract_text_prompt(prompt)
        text_prompt = 'Transcribe this audio' if text_prompt.nil? || text_prompt.empty?

        # TODO: I don't think that "prompt" would ever be an audio filepath.
        #       Check prompt to see if it is a PromptManager object that has context_files

        if  prompt.is_a?(String) &&
            File.exist?(prompt)  &&
            audio_file?(prompt)
          begin
            response = if AIA.config.context_files.empty?
                         @chats[model_name].ask(text_prompt)
                       else
                         @chats[model_name].ask(text_prompt, with: AIA.config.context_files)
                       end
            response.content
          rescue StandardError => e
            "Error transcribing audio: #{e.message}"
          end
        else
          # Fall back to regular chat if no valid audio file is found
          text_to_text_single(prompt, model_name)
        end
      end
    end
  end
end
