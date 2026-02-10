# lib/aia/adapter/chat_execution.rb
# frozen_string_literal: true

module AIA
  module Adapter
    module ChatExecution
      def chat(prompt)
        if @models.size == 1
          single_model_chat(prompt, @models.first)
        else
          multi_model_chat(prompt)
        end
      end

      def single_model_chat(prompt, internal_id)
        chat_instance = @chats[internal_id]
        modes = chat_instance.model.modalities

        # TODO: Need to consider how to handle multi-mode models
        if modes.text_to_text?
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
      end

      # Clear the chat context/history
      # Needed for the /clear and /restore directives
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
          puts "\nFailed to initialize the following models:"
          failed_models.each { |failure| puts "   - #{failure}" }
        end

        # If no models initialized successfully, exit
        if valid_chats.empty?
          puts "\nNo valid models could be initialized. Exiting."
          puts "\nAvailable models can be listed with: bin/aia --help models"
          exit 1
        end

        @chats = valid_chats
        @contexts = valid_contexts
        @model_specs = valid_specs
        @models = valid_chats.keys

        # Report successful models
        if failed_models.any?
          puts "\nSuccessfully initialized: #{@models.join(', ')}"
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
            error_msg = "'#{model_name}' is not a valid LM Studio model.\n\n"
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
          raise if e.message.include?("not a valid LM Studio") || e.message.include?("Cannot connect")
          raise "Error connecting to LM Studio: #{e.message}"
        end
      end

      private

      def load_tools_lazy_mcp_support_only_when_needed
        mcp_connector = McpConnector.new
        tool_loader = ToolLoader.new(mcp_connector)

        @tools = tool_loader.load_tools_with_mcp
        @tools = ToolFilter.filter_allowed(@tools)
        @tools = ToolFilter.filter_rejected(@tools)
        @tools = ToolFilter.drop_duplicates(@tools)

        if tools.empty?
          AIA.config.tool_names = ''
          AIA.config.loaded_tools = []
        else
          AIA.config.tool_names = @tools.map(&:name).join(', ')
          AIA.config.loaded_tools = @tools
        end
      end
    end
  end
end
