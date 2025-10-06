# lib/aia/ruby_llm_adapter.rb

require 'async'
require_relative '../extensions/ruby_llm/provider_fix'

module AIA
  class RubyLLMAdapter
    attr_reader :tools

    def initialize
      @models = extract_models_config
      @chats = {}

      configure_rubyllm
      refresh_local_model_registry
      setup_chats_with_tools
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
        # For osaurus: Use model name prefix "osaurus/" and set OSAURUS_API_BASE env var
        # For LM Studio: Use model name prefix "lms/" and set LMS_API_BASE env var
        config.openai_api_base = ENV.fetch('OPENAI_API_BASE', nil) # e.g., "https://your-azure.openai.azure.com"

        # --- Default Models ---
        # Used by RubyLLM.chat, RubyLLM.embed, RubyLLM.paint if no model is specified.
        # config.default_model            = 'gpt-4.1-nano'            # Default: 'gpt-4.1-nano'
        # config.default_embedding_model  = 'text-embedding-3-small'  # Default: 'text-embedding-3-small'
        # config.default_image_model      = 'dall-e-3'                # Default: 'dall-e-3'

        # --- Connection Settings ---
        config.request_timeout            = 120 # Request timeout in seconds (default: 120)
                config.max_retries                = 3   # Max retries on transient network errors (default: 3)
                config.retry_interval             = 0.1 # Initial delay in seconds (default: 0.1)
                config.retry_backoff_factor       = 2   # Multiplier for subsequent retries (default: 2)
                config.retry_interval_randomness  = 0.5 # Jitter factor (default: 0.5)

        # Connection pooling settings removed - not supported in current RubyLLM version
        # config.connection_pool_size       = 10  # Number of connections to maintain in pool
        # config.connection_pool_timeout    = 60  # Connection pool timeout in seconds
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


    def setup_chats_with_tools
      valid_chats = {}
      failed_models = []

      @models.each do |model_name|
        begin
          # Check if this is a local provider model and handle it specially
          if model_name.start_with?('ollama/')
            # For Ollama models, extract the actual model name and use assume_model_exists
            actual_model = model_name.sub('ollama/', '')
            chat = RubyLLM.chat(model: actual_model, provider: 'ollama', assume_model_exists: true)
          elsif model_name.start_with?('osaurus/')
            # For Osaurus models (OpenAI-compatible), create a custom context with the right API base
            actual_model = model_name.sub('osaurus/', '')
            custom_config = RubyLLM.config.dup
            custom_config.openai_api_base = ENV.fetch('OSAURUS_API_BASE', 'http://localhost:11434/v1')
            custom_config.openai_api_key = 'dummy' # Local servers don't need a real API key
            context = RubyLLM::Context.new(custom_config)
            chat = context.chat(model: actual_model, provider: 'openai', assume_model_exists: true)
          elsif model_name.start_with?('lms/')
            # For LM Studio models (OpenAI-compatible), create a custom context with the right API base
            actual_model = model_name.sub('lms/', '')
            lms_api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234/v1')

            # Validate model exists in LM Studio
            validate_lms_model!(actual_model, lms_api_base)

            custom_config = RubyLLM.config.dup
            custom_config.openai_api_base = lms_api_base
            custom_config.openai_api_key = 'dummy' # Local servers don't need a real API key
            context = RubyLLM::Context.new(custom_config)
            chat = context.chat(model: actual_model, provider: 'openai', assume_model_exists: true)
          else
            chat = RubyLLM.chat(model: model_name)
          end
          valid_chats[model_name] = chat
        rescue StandardError => e
          failed_models << "#{model_name}: #{e.message}"
        end
      end

      # Report failed models but continue with valid ones
      unless failed_models.empty?
        puts "\n❌ Failed to initialize the following models:"
        failed_models.each { |failure| puts "   - #{failure}" }
      end

      # If no models initialized successfully, exit
      if valid_chats.empty?
        puts "\n❌ No valid models could be initialized. Exiting."
        puts "\n💡 Available models can be listed with: bin/aia --help models"
        exit 1
      end

      @chats = valid_chats
      @models = valid_chats.keys

      # Update the config to reflect only the valid models
      AIA.config.model = @models

      # Report successful models
      if failed_models.any?
        puts "\n✅ Successfully initialized: #{@models.join(', ')}"
        puts
      end

      # Use the first chat to determine tool support (assuming all models have similar tool support)
      first_chat = @chats.values.first
      return unless first_chat&.model&.supports_functions?

      load_tools_lazy_mcp_support_only_when_needed

      @chats.each_value do |chat|
        chat.with_tools(*tools) unless tools.empty?
      end
    end


    def load_tools_lazy_mcp_support_only_when_needed
      @tools = []

      support_local_tools
      support_mcp_lazy
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


    def support_mcp_lazy
      # Only load MCP tools if MCP servers are actually configured
      return if AIA.config.mcp_servers.nil? || AIA.config.mcp_servers.empty?

      begin
        RubyLLM::MCP.establish_connection
        @tools += RubyLLM::MCP.tools
      rescue StandardError => e
        warn "Warning: Failed to connect MCP clients: #{e.message}"
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


    def chat(prompt)
      result = if @models.size == 1
        # Single model - use the original behavior
        single_model_chat(prompt, @models.first)
      else
        # Multiple models - use concurrent processing
        multi_model_chat(prompt)
      end

      result
    end

    def single_model_chat(prompt, model_name)
      chat_instance = @chats[model_name]
      modes = chat_instance.model.modalities

      # TODO: Need to consider how to handle multi-mode models
      result = if modes.text_to_text?
        text_to_text_single(prompt, model_name)
      elsif modes.image_to_text?
        image_to_text_single(prompt, model_name)
      elsif modes.text_to_image?
        text_to_image_single(prompt, model_name)
      elsif modes.text_to_audio?
        text_to_audio_single(prompt, model_name)
      elsif modes.audio_to_text?
        audio_to_text_single(prompt, model_name)
      else
        # TODO: what else can be done?
        "Error: No matching modality for model #{model_name}"
      end

      result
    end

    def multi_model_chat(prompt)
      results = {}

      Async do |task|
        @models.each do |model_name|
          task.async do
            begin
              result = single_model_chat(prompt, model_name)
              results[model_name] = result
            rescue StandardError => e
              results[model_name] = "Error with #{model_name}: #{e.message}"
            end
          end
        end
      end

      # Format and return results from all models
      format_multi_model_results(results)
    end

    def format_multi_model_results(results)
      use_consensus = should_use_consensus_mode?

      if use_consensus
        # Generate consensus response using primary model
        generate_consensus_response(results)
      else
        # Show individual responses from all models
        format_individual_responses(results)
      end
    end

    def should_use_consensus_mode?
      # Only use consensus when explicitly enabled with --consensus flag
      AIA.config.consensus == true
    end

    def generate_consensus_response(results)
      primary_model = @models.first
      primary_chat = @chats[primary_model]

      # Build the consensus prompt with all model responses
      consensus_prompt = build_consensus_prompt(results)

      begin
        # Have the primary model generate the consensus
        consensus_result = primary_chat.ask(consensus_prompt).content

        # Format the consensus response
        "from: #{primary_model} (consensus)\n#{consensus_result}"
      rescue StandardError => e
        # If consensus fails, fall back to individual responses
        "Error generating consensus: #{e.message}\n\n" + format_individual_responses(results)
      end
    end

    def build_consensus_prompt(results)
      prompt_parts = []
      prompt_parts << "You are tasked with creating a consensus response based on multiple AI model responses to the same query."
      prompt_parts << "Please analyze the following responses and provide a unified, comprehensive answer that:"
      prompt_parts << "- Incorporates the best insights from all models"
      prompt_parts << "- Resolves any contradictions with clear reasoning"
      prompt_parts << "- Provides additional context or clarification when helpful"
      prompt_parts << "- Maintains accuracy and avoids speculation"
      prompt_parts << ""
      prompt_parts << "Model responses:"
      prompt_parts << ""

      results.each do |model_name, result|
        # Extract content from RubyLLM::Message if needed
        content = if result.respond_to?(:content)
                    result.content
                  else
                    result.to_s
                  end
        next if content.start_with?("Error with")
        prompt_parts << "#{model_name}:"
        prompt_parts << content
        prompt_parts << ""
      end

      prompt_parts << "Please provide your consensus response:"
      prompt_parts.join("\n")
    end

    def format_individual_responses(results)
      # For metrics support, return a special structure if all results have token info
      has_metrics = results.values.all? { |r| r.respond_to?(:input_tokens) && r.respond_to?(:output_tokens) }

      if has_metrics && AIA.config.show_metrics
        # Return structured data that preserves metrics for multi-model
        format_multi_model_with_metrics(results)
      else
        # Original string formatting for non-metrics mode
        output = []
        results.each do |model_name, result|
          output << "from: #{model_name}"
          # Extract content from RubyLLM::Message if needed
          content = if result.respond_to?(:content)
                      result.content
                    else
                      result.to_s
                    end
          output << content
          output << "" # Add blank line between results
        end
        output.join("\n")
      end
    end

    def format_multi_model_with_metrics(results)
      # Create a composite response that includes all model responses and metrics
      formatted_content = []
      metrics_data = []

      results.each do |model_name, result|
        formatted_content << "from: #{model_name}"
        formatted_content << result.content
        formatted_content << ""

        # Collect metrics for each model
        metrics_data << {
          model_id: model_name,
          input_tokens: result.input_tokens,
          output_tokens: result.output_tokens
        }
      end

      # Return a special MultiModelResponse that ChatProcessorService can handle
      MultiModelResponse.new(formatted_content.join("\n"), metrics_data)
    end

    # Helper class to carry multi-model response with metrics
    class MultiModelResponse
      attr_reader :content, :metrics_list

      def initialize(content, metrics_list)
        @content = content
        @metrics_list = metrics_list
      end

      def multi_model?
        true
      end
    end


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
    # Needed for the //clear and //restore directives
    def clear_context
      @chats.each do |model_name, chat|
        # Option 1: Directly clear the messages array in the current chat object
        if chat.instance_variable_defined?(:@messages)
          chat.instance_variable_get(:@messages)
          # Force a completely empty array, not just attempting to clear it
          chat.instance_variable_set(:@messages, [])
        end
      end

      # Option 2: Force RubyLLM to create a new chat instance at the global level
      # This ensures any shared state is reset
      RubyLLM.instance_variable_set(:@chat, nil) if RubyLLM.instance_variable_defined?(:@chat)

      # Option 3: Try to create fresh chat instances, but don't exit on failure
      # This is safer for use in directives like //restore
      old_chats = @chats
      @chats = {} # First clear the chats hash

      begin
        @models.each do |model_name|
          # Try to recreate each chat, but if it fails, keep the old one
          begin
            # Check if this is a local provider model and handle it specially
            if model_name.start_with?('ollama/')
              actual_model = model_name.sub('ollama/', '')
              @chats[model_name] = RubyLLM.chat(model: actual_model, provider: 'ollama', assume_model_exists: true)
            elsif model_name.start_with?('osaurus/')
              actual_model = model_name.sub('osaurus/', '')
              custom_config = RubyLLM.config.dup
              custom_config.openai_api_base = ENV.fetch('OSAURUS_API_BASE', 'http://localhost:11434/v1')
              custom_config.openai_api_key = 'dummy'
              context = RubyLLM::Context.new(custom_config)
              @chats[model_name] = context.chat(model: actual_model, provider: 'openai', assume_model_exists: true)
            elsif model_name.start_with?('lms/')
              actual_model = model_name.sub('lms/', '')
              lms_api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234/v1')

              # Validate model exists in LM Studio
              validate_lms_model!(actual_model, lms_api_base)

              custom_config = RubyLLM.config.dup
              custom_config.openai_api_base = lms_api_base
              custom_config.openai_api_key = 'dummy'
              context = RubyLLM::Context.new(custom_config)
              @chats[model_name] = context.chat(model: actual_model, provider: 'openai', assume_model_exists: true)
            else
              @chats[model_name] = RubyLLM.chat(model: model_name)
            end

            # Re-add tools if they were previously loaded
            if @tools && !@tools.empty? && @chats[model_name].model&.supports_functions?
              @chats[model_name].with_tools(*@tools)
            end
          rescue StandardError => e
            # If we can't create a new chat, keep the old one but clear its context
            warn "Warning: Could not recreate chat for #{model_name}: #{e.message}. Keeping existing instance."
            @chats[model_name] = old_chats[model_name]
            # Clear the old chat's messages if possible
            if @chats[model_name] && @chats[model_name].instance_variable_defined?(:@messages)
              @chats[model_name].instance_variable_set(:@messages, [])
            end
          end
        end
      rescue StandardError => e
        # If something went terribly wrong, restore the old chats but clear their contexts
        warn "Warning: Error during context clearing: #{e.message}. Attempting to recover."
        @chats = old_chats
        @chats.each_value do |chat|
          if chat.instance_variable_defined?(:@messages)
            chat.instance_variable_set(:@messages, [])
          end
        end
      end

      # Option 4: Call official clear_history method if it exists
      @chats.each_value do |chat|
        chat.clear_history if chat.respond_to?(:clear_history)
      end

      # Final verification
      @chats.each_value do |chat|
        if chat.instance_variable_defined?(:@messages) && !chat.instance_variable_get(:@messages).empty?
          chat.instance_variable_set(:@messages, [])
        end
      end

      return 'Chat context successfully cleared.'
    rescue StandardError => e
      return "Error clearing chat context: #{e.message}"
    end


    def method_missing(method, *args, &block)
      # Use the first chat instance for backward compatibility with method_missing
      first_chat = @chats.values.first
      if first_chat&.respond_to?(method)
        first_chat.public_send(method, *args, &block)
      else
        super
      end
    end


    def respond_to_missing?(method, include_private = false)
      # Check if any of our chat instances respond to the method
      @chats.values.any? { |chat| chat.respond_to?(method) } || super
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


    def validate_lms_model!(model_name, api_base)
      require 'net/http'
      require 'json'

      # Build the /v1/models endpoint URL
      uri = URI("#{api_base.gsub(%r{/v1/?$}, '')}/v1/models")

      begin
        response = Net::HTTP.get_response(uri)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Cannot connect to LM Studio at #{api_base}. Is LM Studio running?"
        end

        data = JSON.parse(response.body)
        available_models = data['data']&.map { |m| m['id'] } || []

        unless available_models.include?(model_name)
          error_msg = "❌ '#{model_name}' is not a valid LM Studio model.\n\n"
          if available_models.empty?
            error_msg += "No models are currently loaded in LM Studio.\n"
            error_msg += "Please load a model in LM Studio first."
          else
            error_msg += "Available LM Studio models:\n"
            available_models.each { |m| error_msg += "  - lms/#{m}\n" }
          end
          raise error_msg
        end
      rescue JSON::ParserError => e
        raise "Invalid response from LM Studio at #{api_base}: #{e.message}"
      rescue StandardError => e
        # Re-raise our custom error messages, wrap others
        raise if e.message.start_with?('❌')
        raise "Error connecting to LM Studio: #{e.message}"
      end
    end


    def extract_models_config
      models_config = AIA.config.model

      # Handle backward compatibility - if it's a string, convert to array
      if models_config.is_a?(String)
        [models_config]
      elsif models_config.is_a?(Array)
        models_config
      else
        ['gpt-4o-mini'] # fallback to default
      end
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


    def text_to_image_single(prompt, model_name)
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
        if File.exist?(output_file) && system("which #{AIA.config.speak_command} > /dev/null 2>&1")
          system("#{AIA.config.speak_command} #{output_file}")
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

__END__
