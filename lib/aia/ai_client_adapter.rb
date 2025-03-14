# frozen_string_literal: true

require 'ai_client'

module AIA
  class AIClientAdapter
    def initialize(config)
      @config = config
      
      # Get the model from config
      # Format expected: 'provider/model' or just 'model'
      parts = @config.model.split('/')
      
      if parts.length > 1
        # If provider is specified, use the model part
        @model = parts[1]
      else
        # If no provider specified, use the whole string as model
        @model = parts[0]
      end
      
      # Initialize the AiClient instance with just the model name
      # AiClient will automatically determine the appropriate provider
      @client = AiClient.new(@model)
    end

    def chat(prompt, options = {})
      # For AiClient, we should use the simple string prompt approach
      # or build a more complex message structure if needed
      
      # Set options that are supported by the client
      client_options = {}
      client_options[:temperature] = options[:temperature] || @config.temperature || 0.7
      
      # Only add max_tokens if it's set
      if @config.max_tokens
        client_options[:max_tokens] = options[:max_tokens] || @config.max_tokens
      end
      
      # Add other parameters as needed
      client_options[:image_size] = @config.image_size if @config.image_size && !@config.image_size.empty?
      client_options[:image_quality] = @config.image_quality if @config.image_quality && !@config.image_quality.empty?
      
      # Call chat with the prompt and options
      if client_options.empty?
        @client.chat(prompt)
      else
        @client.chat(prompt, **client_options)
      end
    end

    def speak(text)
      if @config.voice == 'siri' && RUBY_PLATFORM.include?('darwin')
        # Use Mac's say command for Siri voice
        system("say", text)
        return true
      end
      
      # Use AiClient for other voices
      speech_options = {
        provider: 'openai',
        model: @config.speech_model,
        text: text,
        voice: @config.voice
      }
      
      audio_data = AiClient.text_to_speech(**speech_options)
      
      # Play the audio (implementation depends on platform)
      temp_file = Tempfile.new(['speech', '.mp3'])
      temp_file.binmode
      temp_file.write(audio_data)
      temp_file.close
      
      if RUBY_PLATFORM.include?('darwin')
        system("afplay", temp_file.path)
      elsif RUBY_PLATFORM.include?('linux')
        system("mpg123", temp_file.path)
      elsif RUBY_PLATFORM.include?('mingw')
        system("start", temp_file.path)
      end
      
      temp_file.unlink
      true
    end
  end
end
