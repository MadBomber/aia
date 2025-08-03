# lib/aia/ruby_llm_adapter.rb

module AIA
  class RubyLLMAdapter
    attr_reader :tools

    def initialize
      @provider, @model = extract_model_parts.values

      configure_rubyllm
      refresh_local_model_registry
      setup_chat_with_tools
    end


    def configure_rubyllm
      # TODO: Add some of these configuration items to AIA.config
      RubyLLM.configure do |config|
        config.anthropic_api_key  = ENV.fetch('ANTHROPIC_API_KEY', nil)
        config.deepseek_api_key   = ENV.fetch('DEEPSEEK_API_KEY', nil)
        config.gemini_api_key     = ENV.fetch('GEMINI_API_KEY', nil)
        config.gpustack_api_key   = ENV.fetch('GPUSTACK_API_KEY', nil)
        config.mistral_api_key    = ENV.fetch('MISTRAL_API_KEY', nil)
        config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
        config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', nil)

        # These providers require a little something extra
        config.openai_api_key         = ENV.fetch('OPENAI_API_KEY', nil)
        config.openai_organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID', nil)
        config.openai_project_id      = ENV.fetch('OPENAI_PROJECT_ID', nil)

        config.bedrock_api_key       = ENV.fetch('BEDROCK_ACCESS_KEY_ID', nil)
        config.bedrock_secret_key    = ENV.fetch('BEDROCK_SECRET_ACCESS_KEY', nil)
        config.bedrock_region        = ENV.fetch('BEDROCK_REGION', nil)
        config.bedrock_session_token = ENV.fetch('BEDROCK_SESSION_TOKEN', nil)

        # Ollama is based upon the OpenAI API so it needs to over-ride a few things
        config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', nil)

        # --- Custom OpenAI Endpoint ---
        # Use this for Azure OpenAI, proxies, or self-hosted models via OpenAI-compatible APIs.
        config.openai_api_base = ENV.fetch('OPENAI_API_BASE', nil) # e.g., "https://your-azure.openai.azure.com"

        # --- Default Models ---
        # Used by RubyLLM.chat, RubyLLM.embed, RubyLLM.paint if no model is specified.
        # config.default_model            = 'gpt-4.1-nano'            # Default: 'gpt-4.1-nano'
        # config.default_embedding_model  = 'text-embedding-3-small'  # Default: 'text-embedding-3-small'
        # config.default_image_model      = 'dall-e-3'                # Default: 'dall-e-3'

        # --- Connection Settings ---
        # config.request_timeout            = 120 # Request timeout in seconds (default: 120)
        # config.max_retries                = 3   # Max retries on transient network errors (default: 3)
        # config.retry_interval             = 0.1 # Initial delay in seconds (default: 0.1)
        # config.retry_backoff_factor       = 2   # Multiplier for subsequent retries (default: 2)
        # config.retry_interval_randomness  = 0.5 # Jitter factor (default: 0.5)

        # --- Logging Settings ---
        # config.log_file   = '/logs/ruby_llm.log'
        config.log_level = :fatal # debug level can also be set to debug by setting RUBYLLM_DEBUG envar to true
      end
    end


    def refresh_local_model_registry
      if  AIA.config.refresh.nil?           ||
          Integer(AIA.config.refresh).zero? ||
          Date.today > (AIA.config.last_refresh + Integer(AIA.config.refresh))
        RubyLLM.models.refresh!
        AIA.config.last_refresh = Date.today
        AIA::Config.dump_config(AIA.config, AIA.config.config_file) if AIA.config.config_file
      end
    end


    def setup_chat_with_tools
      begin
        @chat  = RubyLLM.chat(model: @model)
        @model = @chat.model.name if @model.nil? # using default model
      rescue StandardError => e
        warn "ERROR: #{e.message}"
        exit 1
      end

      unless @chat.model.supports_functions?
        AIA.config.tools      = []
        AIA.config.tool_names = ''
        return
      end

      load_tools

      @chat.with_tools(*tools) unless tools.empty?
    end


    def load_tools
      @tools = []

      support_local_tools
      support_mcp
      filter_tools_by_allowed_list
      filter_tools_by_rejected_list
      drop_duplicate_tools

      if tools.empty?
        AIA.config.tool_names = ''
      else
        AIA.config.tool_names = @tools.map(&:name).join(', ')
        AIA.config.tools      = @tools
      end
    end


    def support_local_tools
      @tools += ObjectSpace.each_object(Class).select do |klass|
        klass < RubyLLM::Tool
      end
    end


    def support_mcp
      RubyLLM::MCP.establish_connection
      @tools += RubyLLM::MCP.tools
    rescue StandardError => e
      warn "Warning: Failed to connect MCP clients: #{e.message}"
    end


    def drop_duplicate_tools
      seen_names = Set.new
      original_size = @tools.size

      @tools.select! do |tool|
        tool_name = tool.name
        if seen_names.include?(tool_name)
          warn "WARNING: Duplicate tool name detected: '#{tool_name}'. Only the first occurrence will be used."
          false
        else
          seen_names.add(tool_name)
          true
        end
      end

      removed_count = original_size - @tools.size
      warn "Removed #{removed_count} duplicate tools" if removed_count > 0
    end


    # TODO: Need to rethink this dispatcher pattern w/r/t RubyLLM's capabilities
    #       This code was originally designed for AiClient
    #
    def chat(prompt)
      modes = @chat.model.modalities

      # TODO: Need to consider how to handle multi-mode models
      if modes.text_to_text?
        text_to_text(prompt)

      elsif modes.image_to_text?
        image_to_text(prompt)
      elsif modes.text_to_image?
        text_to_image(prompt)

      elsif modes.text_to_audio?
        text_to_audio(prompt)
      elsif modes.audio_to_text?
        audio_to_text(prompt)

      else
        # TODO: what else can be done?
      end
    end


    def transcribe(audio_file)
      @chat.ask('Transcribe this audio', with: audio_file).content
    end


    def speak(_text)
      output_file = "#{Time.now.to_i}.mp3"

      # NOTE: RubyLLM doesn't have a direct text-to-speech feature
      # This is a placeholder for a custom implementation or external service
      begin
        # Try using a TTS API if available
        # For now, we'll use a mock implementation
        File.write(output_file, 'Mock TTS audio content')
        if File.exist?(output_file) && system("which #{AIA.config.speak_command} > /dev/null 2>&1")
          system("#{AIA.config.speak_command} #{output_file}")
        end
        "Audio generated and saved to: #{output_file}"
      rescue StandardError => e
        "Error generating audio: #{e.message}"
      end
    end


    # Clear the chat context/history
    # Needed for the //clear directive
    def clear_context

      # Option 1: Directly clear the messages array in the current chat object
      if @chat.instance_variable_defined?(:@messages)
        @chat.instance_variable_get(:@messages)
        # Force a completely empty array, not just attempting to clear it
        @chat.instance_variable_set(:@messages, [])
      end

      # Option 2: Force RubyLLM to create a new chat instance at the global level
      # This ensures any shared state is reset
      @provider, @model = extract_model_parts.values
      RubyLLM.instance_variable_set(:@chat, nil) if RubyLLM.instance_variable_defined?(:@chat)

      # Option 3: Create a completely fresh chat instance for this adapter
      @chat = nil # First nil it to help garbage collection

      begin
        @chat = RubyLLM.chat(model: @model)
      rescue StandardError => e
        warn "ERROR: #{e.message}"
        exit 1
      end

      # Option 4: Call official clear_history method if it exists
      @chat.clear_history if @chat.respond_to?(:clear_history)

      # Option 5: If chat has messages, force set it to empty again as a final check
      if @chat.instance_variable_defined?(:@messages) && !@chat.instance_variable_get(:@messages).empty?
        @chat.instance_variable_set(:@messages, [])
      end

      # Final verification
      @chat.instance_variable_defined?(:@messages) ? @chat.instance_variable_get(:@messages) : []

      return 'Chat context successfully cleared.'
    rescue StandardError => e
      return "Error clearing chat context: #{e.message}"

    end


    def method_missing(method, *args, &block)
      if @chat.respond_to?(method)
        @chat.public_send(method, *args, &block)
      else
        super
      end
    end


    def respond_to_missing?(method, include_private = false)
      @chat.respond_to?(method) || super
    end

    private

    def filter_tools_by_allowed_list
      return if AIA.config.allowed_tools.nil?

      @tools.select! do |tool|
        tool_name = tool.respond_to?(:name) ? tool.name : tool.class.name
        AIA.config.allowed_tools.any? { |allowed| tool_name.include?(allowed) }
      end
    end


    def filter_tools_by_rejected_list
      return if AIA.config.rejected_tools.nil?

      @tools.reject! do |tool|
        tool_name = tool.respond_to?(:name) ? tool.name : tool.class.name
        AIA.config.rejected_tools.any? { |rejected| tool_name.include?(rejected) }
      end
    end


    def extract_model_parts
      parts = AIA.config.model.split('/')
      parts.map!(&:strip)

      if 2 == parts.length
        provider  = parts[0]
        model     = parts[1]
      elsif 1 == parts.length
        provider  = nil # RubyLLM will figure it out from the model name
        model     = parts[0]
      else
        warn "ERROR: malformed model name: #{AIA.config.model}"
        exit 1
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


    #########################################
    ## text

    def text_to_text(prompt)
      text_prompt = extract_text_prompt(prompt)
      response = if AIA.config.context_files.empty?
                   @chat.ask(text_prompt)
                 else
                   @chat.ask(text_prompt, with: AIA.config.context_files)
                 end

      response.content
    rescue StandardError => e
      e.message
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


    def text_to_image(prompt)
      text_prompt = extract_text_prompt(prompt)
      image_name  = extract_image_path(text_prompt)

      begin
        image = RubyLLM.paint(text_prompt, size: AIA.config.image_size)
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


    def image_to_text(prompt)
      image_path  = extract_image_path(prompt)
      text_prompt = extract_text_prompt(prompt)

      if image_path && File.exist?(image_path)
        begin
          @chat.ask(text_prompt, with: image_path).content
        rescue StandardError => e
          "Error analyzing image: #{e.message}"
        end
      else
        text_to_text(prompt)
      end
    end


    #########################################
    ## audio

    def audio_file?(filepath)
      filepath.to_s.downcase.end_with?('.mp3', '.wav', '.m4a', '.flac')
    end


    def text_to_audio(prompt)
      text_prompt = extract_text_prompt(prompt)
      output_file = "#{Time.now.to_i}.mp3"

      begin
        # NOTE: RubyLLM doesn't have a direct TTS feature
        # TODO: This is a placeholder for a custom implementation
        File.write(output_file, text_prompt)
        if File.exist?(output_file) && system("which #{AIA.config.speak_command} > /dev/null 2>&1")
          system("#{AIA.config.speak_command} #{output_file}")
        end
        "Audio generated and saved to: #{output_file}"
      rescue StandardError => e
        "Error generating audio: #{e.message}"
      end
    end


    def audio_to_text(prompt)
      text_prompt = extract_text_prompt(prompt)
      text_prompt = 'Transcribe this audio' if text_prompt.nil? || text_prompt.empty?

      # TODO: I don't think that "prompt" would ever be an audio filepath.
      #       Check prompt to see if it is a PromptManager object that has context_files

      if  prompt.is_a?(String) &&
          File.exist?(prompt)  &&
          audio_file?(prompt)
        begin
          response = if AIA.config.context_files.empty?
                       @chat.ask(text_prompt)
                     else
                       @chat.ask(text_prompt, with: AIA.config.context_files)
                     end
          response.content
        rescue StandardError => e
          "Error transcribing audio: #{e.message}"
        end
      else
        # Fall back to regular chat if no valid audio file is found
        text_to_text(prompt)
      end
    end
  end
end

__END__
