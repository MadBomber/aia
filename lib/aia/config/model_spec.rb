# frozen_string_literal: true

# lib/aia/config/model_spec.rb
#
# ModelSpec represents a single model configuration with optional role.
# This provides typed access to model configuration instead of raw hashes.
#
# Example:
#   spec = ModelSpec.new(name: 'gpt-4o', role: 'architect')
#   spec.name        # => 'gpt-4o'
#   spec.role        # => 'architect'
#   spec.internal_id # => 'gpt-4o'

module AIA
  class ModelSpec
    # The model id used when a bare provider name is given (e.g. `claude_code`):
    # the provider's own default model.
    DEFAULT_MODEL = 'default'

    attr_accessor :name, :role, :instance, :internal_id, :provider

    def initialize(hash = {})
      hash = hash.transform_keys(&:to_sym) if hash.respond_to?(:transform_keys)

      @name = hash[:name]
      @role = hash[:role]
      @instance = hash[:instance] || 1
      @internal_id = hash[:internal_id] || @name
      @provider = hash[:provider]

      # Extract provider from name if prefixed (e.g., "<provider>/<model-id>")
      extract_provider_from_name! unless @provider
    end

    def to_h
      {
        name: @name,
        role: @role,
        instance: @instance,
        internal_id: @internal_id,
        provider: @provider
      }
    end

    def to_s
      if @role
        "#{@name}=#{@role}"
      else
        @name.to_s
      end
    end

    def ==(other)
      return false unless other.is_a?(ModelSpec)
      name == other.name && role == other.role && instance == other.instance
    end

    def eql?(other)
      self == other
    end

    def hash
      [name, role, instance].hash
    end

    # Check if this model has a role assigned
    def role?
      !@role.nil? && !@role.empty?
    end

    # Check if this is a duplicate instance of the same model
    def duplicate?
      @instance > 1
    end

    # Check if this model uses a local provider
    def local_provider?
      !@provider.nil?
    end

    private

    # Extract a provider from the model name. "<provider>/<model-id>" splits
    # on the slash; a bare "<provider>" with no slash names that provider's
    # DEFAULT_MODEL, which is how agent-CLI providers such as claude_code,
    # codex and copilot are usually given. The prefix is a provider exactly
    # when RubyLLM knows it (registered already, or loadable as a
    # conventional ruby_llm-providers-<prefix> gem) — no provider names are
    # hardcoded here. Names whose first segment is not a provider (registry
    # ids like "meta-llama/llama-4-maverick", plain ids like "gpt-4o") pass
    # through untouched.
    def extract_provider_from_name!
      return if @name.nil?

      prefix, rest = @name.split('/', 2)
      return unless ProviderRegistry.available?(prefix)

      @provider = prefix
      @name = rest || DEFAULT_MODEL
    end
  end
end
