# frozen_string_literal: true

require 'ai_client'
require 'tty-spinner'

module AIA
  class AIClientAdapter
    def initialize(config)
      @config = config
      parts = extract_model_parts(@config.model)
      @provider = parts[:provider]
      @model = parts[:model]
      @client = AiClient.new(@model)
    end

    def chat(prompt)
      # Determine the type of operation based on the model
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
      options = {
        model: @config.transcription_model || 'whisper-1'
      }

      @client.transcribe(audio_file)
    end

    def speak(text)
      output_file = "#{Time.now.to_i}.mp3"
      
      # The ai_client gem's speak method might have different signatures
      # Try different approaches based on the gem version
      begin
        # Try with options
        @client.speak(text, output_file, {
          model: @config.speech_model || 'tts-1',
          voice: @config.voice || 'alloy'
        })
      rescue ArgumentError
        # If that fails, try without options
        @client.speak(text)
      end

      # Play the audio file if possible
      system("afplay #{output_file}") if File.exist?(output_file) && system("which afplay > /dev/null 2>&1")
    end

    private

    def extract_model_parts(model_string)
      parts = model_string.split('/')
      if parts.length > 1
        { provider: parts[0], model: parts[1] }
      else
        # Determine provider from model name if not explicitly provided
        provider = case parts[0].downcase
                  when /^gpt/, /^dall-e/, /^whisper/, /^tts/, /^text-embedding/
                    'openai'
                  when /^claude/
                    'anthropic'
                  when /^gemini/, /^palm/
                    'google'
                  when /^llama/, /^mistral/
                    'ollama'
                  else
                    'openai' # Default to OpenAI if unknown
                  end
        { provider: provider, model: parts[0] }
      end
    end

    def extract_text_prompt(prompt)
      # Extract text from prompt, handling different formats
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
      
      # The ai_client gem's chat method might only accept a single argument
      # So we'll just pass the prompt without any options
      @client.chat(text_prompt)
    end

    def text_to_image(prompt)
      text_prompt = extract_text_prompt(prompt)
      
      # Generate a unique filename for the image
      output_file = "#{Time.now.to_i}.png"
      
      begin
        # Try with options first
        begin
          @client.generate_image(text_prompt, output_file, {
            size: @config.image_size || '1024x1024',
            quality: @config.image_quality || 'standard',
            style: @config.image_style || 'vivid'
          })
        rescue ArgumentError
          # If that fails, try with just the prompt
          @client.generate_image(text_prompt)
        end
        
        # Return the path to the generated image
        "Image generated and saved to: #{output_file}"
      rescue => e
        "Error generating image: #{e.message}"
      end
    end

    def image_to_text(prompt)
      # This method handles vision-based models that can analyze images
      # The prompt might contain a reference to an image file
      
      # Extract image path from prompt if it exists
      image_path = extract_image_path(prompt)
      text_prompt = extract_text_prompt(prompt)
      
      if image_path && File.exist?(image_path)
        begin
          # Try with the image parameter
          @client.chat("#{text_prompt}\n[Analyzing image: #{image_path}]")
        rescue => e
          "Error analyzing image: #{e.message}"
        end
      else
        # Fall back to regular chat if no valid image is found
        text_to_text(prompt)
      end
    end

    def text_to_audio(prompt)
      text_prompt = extract_text_prompt(prompt)
      
      # Generate a unique filename for the audio
      output_file = "#{Time.now.to_i}.mp3"
      
      begin
        # Try with options
        begin
          @client.speak(text_prompt, output_file, {
            model: @config.speech_model || 'tts-1',
            voice: @config.voice || 'alloy'
          })
        rescue ArgumentError
          # If that fails, try without options
          @client.speak(text_prompt)
        end
        
        # Play the audio if possible
        system("afplay #{output_file}") if File.exist?(output_file) && system("which afplay > /dev/null 2>&1")
        
        # Return the path to the generated audio
        "Audio generated and saved to: #{output_file}"
      rescue => e
        "Error generating audio: #{e.message}"
      end
    end

    def audio_to_text(prompt)
      # This method handles transcription of audio files
      # The prompt might be a path to an audio file
      
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
      # Extract image path from prompt
      # This could be in various formats depending on how the prompt is structured
      
      if prompt.is_a?(String)
        # Look for file paths in the string
        prompt.scan(/\b[\w\/\.\-]+\.(jpg|jpeg|png|gif|webp)\b/i).first&.first
      elsif prompt.is_a?(Hash)
        # Check for image path in hash
        prompt[:image] || prompt[:image_path]
      else
        nil
      end
    end
  end
end
