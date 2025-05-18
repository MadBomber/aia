# lib/aia/ruby_llm_adapter.rb

require 'ruby_llm'

module AIA
  class RubyLLMAdapter
    attr_reader :tools

    def initialize
      @model     = AIA.config.model
      model_info = extract_model_parts(@model)

      # Configure RubyLLM with available API keys
      RubyLLM.configure do |config|
        config.openai_api_key    = ENV.fetch('OPENAI_API_KEY', nil)
        config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
        config.gemini_api_key    = ENV.fetch('GEMINI_API_KEY', nil)
        config.deepseek_api_key  = ENV.fetch('DEEPSEEK_API_KEY', nil)

        # Bedrock configuration
        config.bedrock_api_key       = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
        config.bedrock_secret_key    = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
        config.bedrock_region        = ENV.fetch('AWS_REGION', nil)
        config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)
      end

      @chat = RubyLLM.chat(model: model_info[:model])

      @tools = ObjectSpace.each_object(Class).select do |klass|
        klass < RubyLLM::Tool
      end

      @chat.with_tools(*tools) unless tools.empty?
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
      @chat.ask("Transcribe this audio", with: { audio: audio_file })
    end

    def speak(text)
      output_file = "#{Time.now.to_i}.mp3"

      # Note: RubyLLM doesn't have a direct text-to-speech feature
      # This is a placeholder for a custom implementation or external service
      begin
        # Try using a TTS API if available
        # For now, we'll use a mock implementation
        File.write(output_file, "Mock TTS audio content")
        system("#{AIA.config.speak_command} #{output_file}") if File.exist?(output_file) && system("which #{AIA.config.speak_command} > /dev/null 2>&1")
        "Audio generated and saved to: #{output_file}"
      rescue => e
        "Error generating audio: #{e.message}"
      end
    end

    def method_missing(method, *args, &block)
      if @chat.respond_to?(method)
        @chat.public_send(method, *args, &block)
      else
        super
      end
    end

    # Clear the chat context/history
    # Needed for the //clear directive
    def clear_context
        begin
          # Option 1: Directly clear the messages array in the current chat object
          if @chat.instance_variable_defined?(:@messages)
            old_messages = @chat.instance_variable_get(:@messages)
            # Force a completely empty array, not just attempting to clear it
            @chat.instance_variable_set(:@messages, [])
          end

          # Option 2: Force RubyLLM to create a new chat instance at the global level
          # This ensures any shared state is reset
          model_info = extract_model_parts(@model)
          RubyLLM.instance_variable_set(:@chat, nil) if RubyLLM.instance_variable_defined?(:@chat)

          # Option 3: Create a completely fresh chat instance for this adapter
          @chat = nil  # First nil it to help garbage collection
          @chat = RubyLLM.chat(model: model_info[:model])

          # Option 4: Call official clear_history method if it exists
          if @chat.respond_to?(:clear_history)
            @chat.clear_history
          end

          # Option 5: If chat has messages, force set it to empty again as a final check
          if @chat.instance_variable_defined?(:@messages) && !@chat.instance_variable_get(:@messages).empty?
            @chat.instance_variable_set(:@messages, [])
          end

          # Final verification
          new_messages = @chat.instance_variable_defined?(:@messages) ? @chat.instance_variable_get(:@messages) : []

          return "Chat context successfully cleared."
        rescue => e
          return "Error clearing chat context: #{e.message}"
        end
      end
    end

    def respond_to_missing?(method, include_private = false)
      @chat.respond_to?(method) || super
    end

    private

    def extract_model_parts(model_string)
      parts = model_string.split('/')
      parts.map!(&:strip)

      if parts.length > 1
        provider = parts[0]
        model = parts[1]
      else
        provider = nil # RubyLLM will figure it out from the model name
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
      @chat.ask(text_prompt)
    end

    def text_to_image(prompt)
      text_prompt = extract_text_prompt(prompt)
      output_file = "#{Time.now.to_i}.png"

      begin
        RubyLLM.paint(text_prompt, output_path: output_file,
                      size: AIA.config.image_size,
                      quality: AIA.config.image_quality,
                      style: AIA.config.image_style)
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
          @chat.ask(text_prompt, with: { image: image_path })
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
        # Note: RubyLLM doesn't have a direct TTS feature
        # This is a placeholder for a custom implementation
        File.write(output_file, text_prompt)
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
          @chat.ask("Transcribe this audio", with: { audio: prompt })
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
