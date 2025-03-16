# lib/aia/ai_client_adapter.rb
# lib/aia/ai_client_adapter.rb
#
# This file adapts the AI client for use in the AIA application.

require 'ai_client'
require 'tty-spinner'

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  # The AIClientAdapter class adapts the AI client for use in the AIA
  # application, providing methods for interacting with AI models for
  # various operations such as text generation, image generation, and
  # speech synthesis.
  class AIClientAdapter
    # Initializes a new AIClientAdapter with the given configuration.
    #
    # @param config [OpenStruct] the configuration object
    def initialize(config)
      @config = config
      parts = extract_model_parts(@config.model)
      @provider = parts[:provider]
      @model = parts[:model]
      @client = AiClient.new(@model, provider: @provider)
    end

    # Sends a prompt to the AI client for processing based on the model type.
    #
    # @param prompt [String] the prompt text to send
    # @return [String] the response from the AI client
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

    # Transcribes an audio file using the configured transcription model.
    #
    # @param audio_file [String] the path to the audio file to transcribe
    # @return [String] the transcribed text
    def transcribe(audio_file)
      options = {
        model: @config.transcription_model
      }

      @client.transcribe(audio_file)
    end

    # Converts text to speech and plays the audio using the configured
    # speech model and voice.
    #
    # @param text [String] the text to convert to speech
    def speak(text)
      output_file = "#{Time.now.to_i}.mp3"

      # The ai_client gem's speak method might have different signatures
      # Try different approaches based on the gem version
      begin
        # Try with options
        @client.speak(text, output_file, {
          model: @config.speech_model,
          voice: @config.voice
        })
      rescue ArgumentError
        # If that fails, try without options
        @client.speak(text)
      end

      # Play the audio file if possible
      system("#{@config.speak_command} #{output_file}") if File.exist?(output_file) && system("which #{@config.speak_command} > /dev/null 2>&1")
    end

    private

    # Extracts the provider and model parts from a model string.
    #
    # @param model_string [String] the model string to extract from
    # @return [Hash] a hash containing the provider and model
    def extract_model_parts(model_string)
      parts = model_string.split('/')
      parts.map!(&:strip)

      if parts.length > 1
        { provider: parts[0], model: parts[1] }
      else
        provider = nil
        model = parts[0]
        { provider: provider, model: model }
      end
    end

    # Extracts the text portion of a prompt, handling different formats.
    #
    # @param prompt [String, Hash] the prompt to extract text from
    # @return [String] the extracted text
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

    # Processes a text-to-text operation using the AI client.
    #
    # @param prompt [String] the prompt text to process
    # @return [String] the response from the AI client
    def text_to_text(prompt)
      text_prompt = extract_text_prompt(prompt)
      @client.chat(text_prompt)
    end

    # Processes a text-to-image operation using the AI client, generating
    # an image based on the prompt text.
    #
    # @param prompt [String] the prompt text to process
    # @return [String] the path to the generated image
    def text_to_image(prompt)
      text_prompt = extract_text_prompt(prompt)

      # Generate a unique filename for the image
      output_file = "#{Time.now.to_i}.png"

      begin
        # Try with options first
        begin
          @client.generate_image(text_prompt, output_file, {
            size: @config.image_size,
            quality: @config.image_quality,
            style: @config.image_style
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

    # Processes an image-to-text operation using the AI client, analyzing
    # an image and returning a textual description.
    #
    # @param prompt [String] the prompt text containing an image reference
    # @return [String] the response from the AI client
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

    # Processes a text-to-audio operation using the AI client, generating
    # audio from the prompt text.
    #
    # @param prompt [String] the prompt text to process
    # @return [String] the path to the generated audio
    def text_to_audio(prompt)
      text_prompt = extract_text_prompt(prompt)

      # Generate a unique filename for the audio
      output_file = "#{Time.now.to_i}.mp3"

      begin
        # Try with options
        begin
          @client.speak(text_prompt, output_file, {
            model: @config.speech_model,
            voice: @config.voice
          })
        rescue ArgumentError
          # If that fails, try without options
          @client.speak(text_prompt)
        end

        # Play the audio if possible
        system("#{@config.speak_command} #{output_file}") if File.exist?(output_file) && system("which #{@config.speak_command} > /dev/null 2>&1")

        # Return the path to the generated audio
        "Audio generated and saved to: #{output_file}"
      rescue => e
        "Error generating audio: #{e.message}"
      end
    end

    # Processes an audio-to-text operation using the AI client, transcribing
    # an audio file to text.
    #
    # @param prompt [String] the prompt text or path to an audio file
    # @return [String] the transcribed text or response from the AI client
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

    # Extracts the image path from a prompt, handling various formats.
    #
    # @param prompt [String, Hash] the prompt to extract the image path from
    # @return [String, nil] the extracted image path or nil if not found
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
