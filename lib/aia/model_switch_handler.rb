# frozen_string_literal: true

# lib/aia/model_switch_handler.rb
#
# Handles natural language model-change intent detection.
# When a model-change intent is detected by the classification KB,
# extracts model names, confirms with the user, and reconfigures.

module AIA
  class ModelSwitchHandler
    include HandlerProtocol

    def initialize(alias_registry, ui_presenter)
      @aliases = alias_registry
      @ui = ui_presenter
      @model_exists_cache = {}
    end

    # Natural language model switching via KBS intent detection has been removed.
    # Use the /model directive for model changes.
    #
    # @param context [HandlerContext]
    # @return [Boolean] always false
    def handle(context)
      false
    end

    private

    def handle_switch(intent, config)
      models = extract_model_names(intent[:raw_text])
      return false if models.empty?

      resolved = models.map { |m| @aliases.resolve(m) }
      return confirm_and_apply(config, resolved)
    end

    def handle_compare(intent, config)
      models = extract_model_names(intent[:raw_text])
      return false if models.size < 2

      resolved = models.map { |m| @aliases.resolve(m) }

      @ui.display_info("Interpreted as: compare #{resolved.join(', ')}")
      @ui.display_info("Proceed? (y/n)")

      response = @ui.ask_question
      return false unless response&.strip&.downcase == 'y'

      config.flags.consensus = true
      apply_model_change(config, resolved)
      true
    end

    def handle_capability_switch(intent, config)
      capability = intent[:capability]
      resolved = [@aliases.resolve(capability)]
      return confirm_and_apply(config, resolved)
    end

    def confirm_and_apply(config, resolved)
      @ui.display_info("Interpreted as: /model #{resolved.join(', ')}")
      @ui.display_info("Proceed? (y/n)")

      response = @ui.ask_question
      return false unless response&.strip&.downcase == 'y'

      apply_model_change(config, resolved)
      true
    end

    def extract_model_names(text)
      return [] unless text

      # Check each word against known aliases and model names
      words = text.downcase.scan(/[\w.-]+/)
      words.select { |w| @aliases.known?(w) || model_exists?(w) }.uniq
    end

    def model_exists?(name)
      return @model_exists_cache[name] if @model_exists_cache.key?(name)
      @model_exists_cache[name] = begin
        return false unless defined?(RubyLLM) && RubyLLM.respond_to?(:models)
        !!RubyLLM.models.find(name)
      rescue StandardError
        false
      end
    end

    def apply_model_change(config, model_names)
      config.models = model_names.map { |name| AIA::ModelSpec.new(name: name) }

      history_mode = config.respond_to?(:model_switch_history) ?
        config.model_switch_history&.to_sym : :clean

      AIA.client = RobotFactory.rebuild(config, history_mode: history_mode)
      @ui.display_info("Model switched to: #{model_names.join(', ')}")
    end
  end
end
