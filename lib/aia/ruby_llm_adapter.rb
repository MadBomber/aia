# lib/aia/ruby_llm_adapter.rb
# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative '../extensions/ruby_llm/provider_fix'
require_relative 'adapter/gem_activator'
require_relative 'adapter/provider_configurator'
require_relative 'adapter/model_registry'
require_relative 'adapter/tool_loader'
require_relative 'adapter/mcp_connector'
require_relative 'adapter/tool_filter'
require_relative 'adapter/chat_execution'
require_relative 'adapter/multi_model_chat'
require_relative 'adapter/modality_handlers'
require_relative 'adapter/error_handler'

module AIA
  class RubyLLMAdapter
    include Adapter::ChatExecution
    include Adapter::MultiModelChat
    include Adapter::ModalityHandlers
    include Adapter::ErrorHandler

    # Re-export for backward compatibility (tests reference AIA::RubyLLMAdapter::MultiModelResponse)
    MultiModelResponse = Adapter::MultiModelChat::MultiModelResponse

    attr_reader :tools, :model_specs, :chats

    # Delegates to the first chat instance's model object.
    # Used by single-model callers to inspect the active model.
    def model
      @chats.values.first&.model
    end

    def initialize
      @model_specs = extract_models_config  # Full specs with role info
      @models = extract_model_names(@model_specs)  # Just model names for backward compat
      @chats = {}
      @contexts = {} # Store isolated contexts for each model

      Adapter::ProviderConfigurator.configure
      Adapter::ModelRegistry.new.refresh
      setup_chats_with_tools
    end

    private

    # Helper to access the AIA logger for application-level logging
    def logger
      @logger ||= LoggerManager.aia_logger
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
  end
end
