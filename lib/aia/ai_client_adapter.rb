# lib/aia/ai_client_adapter.rb
#


require 'ai_client'
require 'tty-spinner'


module AIA
  class AIClientAdapter
    def initialize
      @model  = AIA.config.model

      model_info = extract_model_parts(@model)
      @client = AiClient.new(
        model_info[:model],
        provider: model_info[:provider]
      )
    end


    def chat(prompt)
      if @model.downcase.include?('dall-e') || @model.downcase.include?('image-generation')
        text_to_image(prompt)
      elsif @model.downcase.include?('vision') || @model.downcase.include?('image')
        image_to_text(prompt)
      elsif @model.downcase.include?('tts') || @model.downcase.include?('speech')
        text_to_audio(prompt)
      elsif @model.downcase.include?('whisper') || @model.downcase.include?('transcription')
        audio_to_text(prompt)
      else
        text_to_text(prompt)
      end
    end



    def transcribe(audio_file)
      @client.transcribe(audio_file)
    end



    def speak(text)
      output_file = "#{Time.now.to_i}.mp3"

      begin
        # Try with options
        @client.speak(text, output_file, {
          model: AIA.config.speech_model,
          voice: AIA.config.voice
        })
      rescue ArgumentError
        @client.speak(text)
      end

      system("#{AIA.config.speak_command} #{output_file}") if File.exist?(output_file) && system("which #{AIA.config.speak_command} > /dev/null 2>&1")
    end

    def method_missing(method, *args, &block)
      if @client.respond_to?(method)
        @client.public_send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @client.respond_to?(method) || super
    end

    private



    def extract_model_parts(model_string)
      parts = model_string.split('/')
      parts.map!(&:strip)

      if parts.length > 1
        provider = parts[0]
        model = parts[1]
      else
        provider = nil # AiClient will figure it out from the model name
        model = parts[0]
      end



      { provider: provider, model: model }
    end



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



    def text_to_text(prompt)
      text_prompt = extract_text_prompt(prompt)
      @client.chat(text_prompt)
    end



    def text_to_image(prompt)
      text_prompt = extract_text_prompt(prompt)


      output_file = "#{Time.now.to_i}.png"

      begin
        begin
          @client.generate_image(text_prompt, output_file, {
            size:    AIA.config.image_size,
            quality: AIA.config.image_quality,
            style:   AIA.config.image_style
          })
        rescue ArgumentError
          @client.generate_image(text_prompt)
        end

        "Image generated and saved to: #{output_file}"
      rescue => e
        "Error generating image: #{e.message}"
      end
    end



    def image_to_text(prompt)
      image_path = extract_image_path(prompt)
      text_prompt = extract_text_prompt(prompt)

      if image_path && File.exist?(image_path)
        begin
          @client.chat("#{text_prompt}\n[Analyzing image: #{image_path}]")
        rescue => e
          "Error analyzing image: #{e.message}"
        end
      else
        text_to_text(prompt)
      end
    end



    def text_to_audio(prompt)
      text_prompt = extract_text_prompt(prompt)

      output_file = "#{Time.now.to_i}.mp3"

      begin
        begin
          @client.speak(text_prompt, output_file, {
            model: AIA.config.speech_model,
            voice: AIA.config.voice
          })
        rescue ArgumentError
          @client.speak(text_prompt)
        end

        system("#{AIA.config.speak_command} #{output_file}") if File.exist?(output_file) && system("which #{AIA.config.speak_command} > /dev/null 2>&1")

        "Audio generated and saved to: #{output_file}"
      rescue => e
        "Error generating audio: #{e.message}"
      end
    end



    def audio_to_text(prompt)
      if prompt.is_a?(String) && File.exist?(prompt) &&
         prompt.downcase.end_with?('.mp3', '.wav', '.m4a', '.flac')
        begin
          @client.transcribe(prompt)
        rescue => e
          "Error transcribing audio: #{e.message}"
        end
      else
        # Fall back to regular chat if no valid audio file is found
        text_to_text(prompt)
      end
    end



    def extract_image_path(prompt)
      if prompt.is_a?(String)
        prompt.scan(/\b[\w\/\.\-]+\.(jpg|jpeg|png|gif|webp)\b/i).first&.first
      elsif prompt.is_a?(Hash)
        prompt[:image] || prompt[:image_path]
      else
        nil
      end
    end
  end
end
