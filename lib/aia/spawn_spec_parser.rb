# frozen_string_literal: true

require_relative 'config/model_spec'

module AIA
  # Parses the explicit form of the /spawn directive into a spawn spec:
  #
  #   /spawn <name> <provider/model> <system prompt...>
  #
  # The second token is parsed as a model via {ModelSpec}, so
  # "ollama/qwen3.6:latest" yields model "qwen3.6:latest" + provider "ollama"
  # (and "lms/..." maps to the openai provider). Use "-" or "inherit" as the
  # model token to keep the parent robot's model and provider.
  class SpawnSpecParser
    INHERIT_TOKENS = %w[- inherit].freeze

    # @param args [Array<String>] directive args (two or more expected)
    # @return [Hash] {name:, model:, provider:, system_prompt:}
    def self.parse(args)
      name = args[0]
      model, provider = parse_model(args[1])
      system_prompt = args[2..].to_a.join(' ').strip
      system_prompt = nil if system_prompt.empty?

      { name: name, model: model, provider: provider, system_prompt: system_prompt }
    end

    # Split a "provider/model" token into [model, provider]. Returns [nil, nil]
    # to signal the spawned robot should inherit its parent's model/provider.
    #
    # @param token [String, nil]
    # @return [Array(String, String)]
    def self.parse_model(token)
      return [nil, nil] if token.nil? || INHERIT_TOKENS.include?(token.downcase)

      spec     = ModelSpec.new(name: token)
      provider = spec.provider == 'lms' ? 'openai' : spec.provider
      [spec.name, provider]
    end
  end
end
