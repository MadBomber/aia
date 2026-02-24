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
    attr_accessor :name, :role, :instance, :internal_id, :provider

    # Provider prefixes that map to RubyLLM provider slugs.
    # 'lms' is stored as-is; RobotFactory maps it to the openai provider
    # with a custom API base so it doesn't conflict with real OpenAI models.
    PROVIDER_ALIASES = {
      'ollama' => 'ollama',
      'lms'    => 'lms',
    }.freeze

    def initialize(hash = {})
      hash = hash.transform_keys(&:to_sym) if hash.respond_to?(:transform_keys)

      @name = hash[:name]
      @role = hash[:role]
      @instance = hash[:instance] || 1
      @internal_id = hash[:internal_id] || @name
      @provider = hash[:provider]

      # Extract provider from name if prefixed (e.g., "ollama/llama3" or "lms/my-model")
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

    # Extract provider prefix from model name.
    # "ollama/llama3:latest" => provider: "ollama", name: "llama3:latest"
    # "lms/my-model" => provider: "openai", name: "my-model"
    def extract_provider_from_name!
      return unless @name&.include?('/')

      prefix, rest = @name.split('/', 2)
      if PROVIDER_ALIASES.key?(prefix)
        @provider = PROVIDER_ALIASES[prefix]
        @name = rest
      end
    end
  end
end
