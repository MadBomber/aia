# lib/aia/ruby_llm_adapter.rb

require 'async'
require 'fileutils'
require 'json'
require_relative '../extensions/ruby_llm/provider_fix'

module AIA
  class RubyLLMAdapter
    attr_reader :tools, :model_specs, :chats

    def initialize
      @model_specs = extract_models_config  # Full specs with role info
      @models = extract_model_names(@model_specs)  # Just model names for backward compat
      @chats = {}
      @contexts = {} # Store isolated contexts for each model

      configure_rubyllm
      refresh_local_model_registry
      setup_chats_with_tools
    end


    def configure_rubyllm
      # TODO: Add some of these configuration items to AIA.config
      # Note: RubyLLM supports specific providers. Use provider prefix (e.g., "xai/grok-beta")
      # for providers not directly configured here.
      RubyLLM.configure do |config|
        config.anthropic_api_key  = ENV.fetch('ANTHROPIC_API_KEY', nil)
        config.deepseek_api_key   = ENV.fetch('DEEPSEEK_API_KEY', nil)
        config.gemini_api_key     = ENV.fetch('GEMINI_API_KEY', nil)
        config.gpustack_api_key   = ENV.fetch('GPUSTACK_API_KEY', nil)
        config.mistral_api_key    = ENV.fetch('MISTRAL_API_KEY', nil)
        config.openrouter_api_key = ENV.fetch('OPEN_ROUTER_API_KEY', nil)
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
      return if models_json_path.nil? # Skip if no aia_dir configured

      # Coerce refresh_days to integer (env vars come as strings)
      refresh_days = AIA.config.registry.refresh
      refresh_days = refresh_days.to_i if refresh_days.respond_to?(:to_i)
      refresh_days ||= 7 # Default to 7 days if nil

      last_refresh = models_last_refresh
      models_exist = !last_refresh.nil?

      # If refresh is disabled (0), just save current models if file doesn't exist
      if refresh_days.zero?
        save_models_to_json unless models_exist
        return
      end

      # Determine if refresh is needed:
      # 1. Always refresh if models.json doesn't exist (initial setup)
      # 2. Otherwise, refresh if enough time has passed
      needs_refresh = if !models_exist
                        true # Initial refresh needed (no models.json)
                      else
                        Date.today > (last_refresh + refresh_days)
                      end

      return unless needs_refresh

      # Refresh models from RubyLLM (fetches latest model info)
      RubyLLM.models.refresh!

      # Save models to JSON file in aia_dir
      save_models_to_json
    end

    def models_json_path
      aia_dir = AIA.config.paths&.aia_dir
      return nil if aia_dir.nil?

      File.join(File.expand_path(aia_dir), 'models.json')
    end

    # Returns the last refresh date based on models.json modification time
    def models_last_refresh
      path = models_json_path
      return nil if path.nil? || !File.exist?(path)

      File.mtime(path).to_date
    end

    def save_models_to_json
      return if models_json_path.nil?

      aia_dir = File.expand_path(AIA.config.paths.aia_dir)
      FileUtils.mkdir_p(aia_dir)

      models_data = RubyLLM.models.all.map(&:to_h)

      File.write(models_json_path, JSON.pretty_generate(models_data))
    end


    # Create an isolated RubyLLM::Context for a model to prevent cross-talk (ADR-002)
    # Each model gets its own context with provider-specific configuration
    def create_isolated_context_for_model(model_name)
      config = RubyLLM.config.dup

      # Apply provider-specific configuration
      if model_name.start_with?('lms/')
        config.openai_api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234/v1')
        config.openai_api_key = 'dummy' # Local servers don't need a real API key
      elsif model_name.start_with?('osaurus/')
        config.openai_api_base = ENV.fetch('OSAURUS_API_BASE', 'http://localhost:11434/v1')
        config.openai_api_key = 'dummy' # Local servers don't need a real API key
      end

      RubyLLM::Context.new(config)
    end


    # Extract the actual model name and provider from the prefixed model_name
    # Returns: [actual_model, provider] where provider may be nil for auto-detection
    def extract_model_and_provider(model_name)
      if model_name.start_with?('ollama/')
        [model_name.sub('ollama/', ''), 'ollama']
      elsif model_name.start_with?('lms/') || model_name.start_with?('osaurus/')
        [model_name.sub(%r{^(lms|osaurus)/}, ''), 'openai']
      else
        [model_name, nil] # Let RubyLLM auto-detect provider
      end
    end


    def setup_chats_with_tools
      valid_chats = {}
      valid_contexts = {}
      valid_specs = []
      failed_models = []

      @model_specs.each do |spec|
        model_name = spec[:model]          # Actual model name (e.g., "gpt-4o")
        internal_id = spec[:internal_id]   # Key for storage (e.g., "gpt-4o#1", "gpt-4o#2")

        begin
          # Create isolated context for this model to prevent cross-talk (ADR-002)
          context = create_isolated_context_for_model(model_name)

          # Determine provider and actual model name
          actual_model, provider = extract_model_and_provider(model_name)

          # Validate LM Studio models
          if model_name.start_with?('lms/')
            lms_api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234/v1')
            validate_lms_model!(actual_model, lms_api_base)
          end

          # Create chat using isolated context
          chat = if provider
                   context.chat(model: actual_model, provider: provider, assume_model_exists: true)
                 else
                   context.chat(model: actual_model)
                 end

          valid_chats[internal_id] = chat
          valid_contexts[internal_id] = context
          valid_specs << spec
        rescue StandardError => e
          failed_models << "#{internal_id}: #{e.message}"
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
      @contexts = valid_contexts
      @model_specs = valid_specs
      @models = valid_chats.keys

      # Update the config to reflect only the valid models (keep as specs)
      # Note: models is an array, not directly settable - skip this update

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
        AIA.config.loaded_tools = []
      else
        AIA.config.tool_names = @tools.map(&:name).join(', ')
        AIA.config.loaded_tools = @tools
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
        AIA.config.loaded_tools = @tools
      end
    end


    def support_local_tools
      # First, load any required libraries specified in config
      load_require_libs

      # Then, load tool files from tools.paths
      load_tool_files

      # Now scan ObjectSpace for RubyLLM::Tool subclasses
      tool_classes = ObjectSpace.each_object(Class).select do |klass|
        next false unless klass < RubyLLM::Tool

        # Filter out tools that can't be instantiated without arguments
        # RubyLLM calls tool.new without args, so we must verify each tool works
        begin
          klass.new
          true
        rescue ArgumentError, LoadError, StandardError
          # Skip tools that require arguments or have missing dependencies
          false
        end
      end

      @tools += tool_classes
    end

    def load_require_libs
      require_libs = AIA.config.require_libs
      return if require_libs.nil? || require_libs.empty?

      require_libs.each do |lib|
        begin
          # Activate gem and add to load path (bypasses Bundler's restrictions)
          activate_gem_for_require(lib)

          require lib

          # After requiring, trigger tool loading if the library supports it
          # This handles gems like shared_tools that use Zeitwerk lazy loading
          trigger_tool_loading(lib)
        rescue LoadError => e
          warn "Warning: Failed to require library '#{lib}': #{e.message}"
          warn "Hint: Make sure the gem is installed: gem install #{lib}"
        rescue StandardError => e
          warn "Warning: Error in library '#{lib}': #{e.class} - #{e.message}"
        end
      end
    end

    # Activate a gem and add its lib path to $LOAD_PATH
    # This bypasses Bundler's restrictions on loading non-bundled gems
    def activate_gem_for_require(lib)
      # First try normal activation
      return if Gem.try_activate(lib)

      # Bundler intercepts Gem::Specification methods, so search gem dirs directly
      gem_path = find_gem_path(lib)
      if gem_path
        lib_path = File.join(gem_path, 'lib')
        $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      end
    end

    # Find gem path by searching gem directories directly
    # This bypasses Bundler's restrictions
    def find_gem_path(gem_name)
      gem_dirs = Gem.path.flat_map do |base|
        gems_dir = File.join(base, 'gems')
        next [] unless File.directory?(gems_dir)

        Dir.glob(File.join(gems_dir, "#{gem_name}-*")).select do |path|
          File.directory?(path) && File.basename(path).match?(/^#{Regexp.escape(gem_name)}-[\d.]+/)
        end
      end

      # Return the most recent version
      gem_dirs.sort.last
    end

    # Some tool libraries use lazy loading (e.g., Zeitwerk) and need explicit
    # triggering to load tool classes into ObjectSpace
    def trigger_tool_loading(lib)
      # Convert lib name to constant (e.g., 'shared_tools' -> SharedTools)
      const_name = lib.split(/[_-]/).map(&:capitalize).join

      begin
        mod = Object.const_get(const_name)

        # Try common methods that libraries use to load tools
        if mod.respond_to?(:load_all_tools)
          mod.load_all_tools
        elsif mod.respond_to?(:tools)
          # Calling .tools often triggers lazy loading
          mod.tools
        end
      rescue NameError
        # Constant doesn't exist, library might use different naming
      end
    end

    def load_tool_files
      paths = AIA.config.tools&.paths
      return if paths.nil? || paths.empty?

      paths.each do |path|
        expanded_path = File.expand_path(path)
        if File.exist?(expanded_path)
          begin
            require expanded_path
          rescue LoadError, StandardError => e
            warn "Warning: Failed to load tool file '#{path}': #{e.message}"
          end
        else
          warn "Warning: Tool file not found: #{path}"
        end
      end
    end


    def support_mcp_lazy
      # Only load MCP tools if MCP servers are actually configured
      return if AIA.config.mcp_servers.nil? || AIA.config.mcp_servers.empty?

      begin
        # Register each MCP server with RubyLLM::MCP
        register_mcp_clients

        RubyLLM::MCP.establish_connection
        @tools += RubyLLM::MCP.tools
      rescue StandardError => e
        warn "Warning: Failed to connect MCP clients: #{e.message}"
      end
    end

    def register_mcp_clients
      AIA.config.mcp_servers.each do |server|
        # Support both symbol and string keys
        name    = server[:name]    || server['name']
        command = server[:command] || server['command']
        args    = server[:args]    || server['args'] || []
        env     = server[:env]     || server['env'] || {}
        timeout = server[:timeout] || server['timeout']

        # Build config - always include args (even if empty) as RubyLLM::MCP requires it
        config = {
          command: command,
          args: Array(args)
        }
        config[:env] = env unless env.empty?

        begin
          # Build add_client options - timeout is a top-level option, not in config
          client_options = {
            name: name,
            transport_type: :stdio,
            config: config
          }
          # Some versions of RubyLLM::MCP support timeout as a top-level option
          client_options[:timeout] = timeout if timeout

          RubyLLM::MCP.add_client(**client_options)
        rescue ArgumentError => e
          # If timeout isn't supported, try without it
          if e.message.include?('timeout')
            RubyLLM::MCP.add_client(
              name: name,
              transport_type: :stdio,
              config: config
            )
          else
            raise
          end
        rescue StandardError => e
          warn "Warning: Failed to register MCP client '#{name}': #{e.message}"
        end
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

    def single_model_chat(prompt, internal_id)
      chat_instance = @chats[internal_id]
      modes = chat_instance.model.modalities

      # TODO: Need to consider how to handle multi-mode models
      result = if modes.text_to_text?
        text_to_text_single(prompt, internal_id)
      elsif modes.image_to_text?
        image_to_text_single(prompt, internal_id)
      elsif modes.text_to_image?
        text_to_image_single(prompt, internal_id)
      elsif modes.text_to_audio?
        text_to_audio_single(prompt, internal_id)
      elsif modes.audio_to_text?
        audio_to_text_single(prompt, internal_id)
      else
        # TODO: what else can be done?
        "Error: No matching modality for model #{internal_id}"
      end

      result
    end

    # Prepend role content to prompt for a specific model (ADR-005)
    def prepend_model_role(prompt, internal_id)
      # Get model spec to find role
      spec = get_model_spec(internal_id)
      return prompt unless spec && spec[:role]

      # Get role content using PromptHandler
      # Need to create PromptHandler instance if not already available
      prompt_handler = AIA::PromptHandler.new
      role_content = prompt_handler.load_role_for_model(spec, AIA.config.prompts.role)

      return prompt unless role_content

      # Prepend role to prompt based on prompt type
      if prompt.is_a?(String)
        # Simple string prompt
        "#{role_content}\n\n#{prompt}"
      elsif prompt.is_a?(Array)
        # Conversation array - prepend to first user message
        prepend_role_to_conversation(prompt, role_content)
      else
        prompt
      end
    end

    def prepend_role_to_conversation(conversation, role_content)
      # Find the first user message and prepend role
      modified = conversation.dup
      first_user_index = modified.find_index { |msg| msg[:role] == "user" || msg["role"] == "user" }

      if first_user_index
        msg = modified[first_user_index].dup
        role_key = msg.key?(:role) ? :role : "role"
        content_key = msg.key?(:content) ? :content : "content"

        msg[content_key] = "#{role_content}\n\n#{msg[content_key]}"
        modified[first_user_index] = msg
      end

      modified
    end

    def multi_model_chat(prompt_or_contexts)
      results = {}

      # Check if we're receiving per-model contexts (Hash) or shared prompt (String/Array) - ADR-002 revised
      per_model_contexts = prompt_or_contexts.is_a?(Hash) &&
                           prompt_or_contexts.keys.all? { |k| @models.include?(k) }

      Async do |task|
        @models.each do |internal_id|
          task.async do
            begin
              # Use model-specific context if available, otherwise shared prompt
              prompt = if per_model_contexts
                         prompt_or_contexts[internal_id]
                       else
                         prompt_or_contexts
                       end

              # Add per-model role if specified (ADR-005)
              prompt = prepend_model_role(prompt, internal_id)

              result = single_model_chat(prompt, internal_id)
              results[internal_id] = result
            rescue StandardError => e
              results[internal_id] = "Error with #{internal_id}: #{e.message}"
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
      AIA.config.flags.consensus == true
    end

    def generate_consensus_response(results)
      primary_model = @models.first
      primary_chat = @chats[primary_model]

      # Build the consensus prompt with all model responses
      # Note: This prompt does NOT include the model's role (ADR-005)
      # The primary model synthesizes neutrally without role bias
      consensus_prompt = build_consensus_prompt(results)

      begin
        # Have the primary model generate the consensus
        # The consensus prompt is already role-neutral
        consensus_result = primary_chat.ask(consensus_prompt).content

        # Format the consensus response - no role label for consensus
        "from: #{primary_model}\n#{consensus_result}"
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
        # Original string formatting for non-metrics mode with role labels (ADR-005)
        output = []
        results.each do |internal_id, result|
          # Get model spec to include role in output
          spec = get_model_spec(internal_id)
          display_name = format_model_display_name(spec)

          output << "from: #{display_name}"
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

    # Format display name with instance number and role (ADR-005)
    def format_model_display_name(spec)
      return spec unless spec.is_a?(Hash)

      model_name = spec[:model]
      instance = spec[:instance]
      role = spec[:role]

      # Add instance number if > 1
      display = if instance > 1
                  "#{model_name} ##{instance}"
                else
                  model_name
                end

      # Add role label if present
      display += " (#{role})" if role

      display
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
        if File.exist?(output_file) && system("which #{AIA.config.audio.speak_command} > /dev/null 2>&1")
          system("#{AIA.config.audio.speak_command} #{output_file}")
        end
        "Audio generated and saved to: #{output_file}"
      rescue StandardError => e
        "Error generating audio: #{e.message}"
      end
    end


    # Clear the chat context/history
    # Needed for the //clear and //restore directives
    # Simplified with ADR-002: Each model has isolated context, no global state to manage
    def clear_context
      old_chats = @chats.dup
      new_chats = {}

      @models.each do |model_name|
        begin
          # Get the isolated context for this model
          context = @contexts[model_name]
          actual_model, provider = extract_model_and_provider(model_name)

          # Create a fresh chat instance from the same isolated context
          chat = if provider
                   context.chat(model: actual_model, provider: provider, assume_model_exists: true)
                 else
                   context.chat(model: actual_model)
                 end

          # Re-add tools if they were previously loaded
          if @tools && !@tools.empty? && chat.model&.supports_functions?
            chat.with_tools(*@tools)
          end

          new_chats[model_name] = chat
        rescue StandardError => e
          # If recreation fails, keep the old chat but clear its messages
          warn "Warning: Could not recreate chat for #{model_name}: #{e.message}. Clearing existing chat."
          chat = old_chats[model_name]
          if chat&.instance_variable_defined?(:@messages)
            chat.instance_variable_set(:@messages, [])
          end
          chat.clear_history if chat&.respond_to?(:clear_history)
          new_chats[model_name] = chat
        end
      end

      @chats = new_chats
      'Chat context successfully cleared.'
    rescue StandardError => e
      "Error clearing chat context: #{e.message}"
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
      allowed = AIA.config.tools.allowed
      return if allowed.nil? || allowed.empty?

      # allowed_tools is now an array
      allowed_list = Array(allowed).map(&:strip)

      @tools.select! do |tool|
        tool_name = tool.respond_to?(:name) ? tool.name : tool.class.name
        allowed_list.any? { |allowed_pattern| tool_name.include?(allowed_pattern) }
      end
    end


    def filter_tools_by_rejected_list
      rejected = AIA.config.tools.rejected
      return if rejected.nil? || rejected.empty?

      # rejected_tools is now an array
      rejected_list = Array(rejected).map(&:strip)

      @tools.reject! do |tool|
        tool_name = tool.respond_to?(:name) ? tool.name : tool.class.name
        rejected_list.any? { |rejected_pattern| tool_name.include?(rejected_pattern) }
      end
    end


    # Handles tool execution crashes gracefully
    # Logs error with short traceback, repairs conversation, and returns error message
    def handle_tool_crash(chat_instance, exception)
      error_msg = "Tool error: #{exception.class} - #{exception.message}"

      # Log error with short traceback (first 5 lines)
      warn "\n⚠️  #{error_msg}"
      if exception.backtrace
        short_trace = exception.backtrace.first(5).map { |line| "   #{line}" }.join("\n")
        warn short_trace
      end
      warn "" # blank line for readability

      # Repair incomplete tool calls to maintain conversation integrity
      repair_incomplete_tool_calls(chat_instance, error_msg)

      # Return error message so conversation can continue
      error_msg
    end


    # Repairs conversation history when a tool call fails (timeout, error, etc.)
    # When an MCP tool times out, the conversation gets into an invalid state:
    # - Assistant message with tool_calls was added to history
    # - But no tool result message was added (because the tool failed)
    # - The API requires tool results for each tool_call_id
    # This method adds synthetic error tool results to fix the conversation.
    def repair_incomplete_tool_calls(chat_instance, error_message)
      return unless chat_instance.respond_to?(:messages)

      messages = chat_instance.messages
      return if messages.empty?

      # Find the last assistant message that has tool_calls
      last_assistant_with_tools = messages.reverse.find do |msg|
        msg.role == :assistant && msg.respond_to?(:tool_calls) && msg.tool_calls&.any?
      end

      return unless last_assistant_with_tools

      # Get the tool_call_ids that need results
      tool_call_ids = last_assistant_with_tools.tool_calls.keys

      # Check which tool_call_ids already have results
      existing_tool_results = messages.select { |m| m.role == :tool }.map(&:tool_call_id).compact

      # Add synthetic error results for any missing tool_call_ids
      tool_call_ids.each do |tool_call_id|
        next if existing_tool_results.include?(tool_call_id.to_s) || existing_tool_results.include?(tool_call_id)

        # Add a synthetic tool result with the error message
        chat_instance.add_message(
          role: :tool,
          content: "Error: #{error_message}",
          tool_call_id: tool_call_id
        )
      end
    rescue StandardError
      # Don't let repair failures cascade
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
      # Use config.models which returns array of ModelSpec objects
      models_config = AIA.config.models

      if models_config.nil? || models_config.empty?
        # Fallback to default
        [{model: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini'}]
      else
        # Convert ModelSpec objects to hash format expected by adapter
        models_config.map do |spec|
          if spec.respond_to?(:name)
            # ModelSpec object
            {model: spec.name, role: spec.role, instance: spec.instance, internal_id: spec.internal_id}
          elsif spec.is_a?(Hash)
            # Hash format (legacy or from config.model accessor)
            model_name = spec[:model] || spec[:name]
            {model: model_name, role: spec[:role], instance: spec[:instance] || 1, internal_id: spec[:internal_id] || model_name}
          elsif spec.is_a?(String)
            # String format (legacy)
            {model: spec, role: nil, instance: 1, internal_id: spec}
          else
            # Unknown format, skip
            nil
          end
        end.compact
      end
    end

    def extract_model_names(model_specs)
      # Extract just the model names from the specs
      # For models with instance > 1, use internal_id (e.g., "gpt-4o#2")
      model_specs.map do |spec|
        spec[:internal_id]
      end
    end

    def get_model_spec(internal_id)
      # Find the spec for a given internal_id
      @model_specs.find { |spec| spec[:internal_id] == internal_id }
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

__END__
