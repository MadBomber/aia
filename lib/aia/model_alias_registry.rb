# frozen_string_literal: true

# lib/aia/model_alias_registry.rb
#
# Configurable alias table that maps short names, provider names,
# and capability descriptors to model IDs.

module AIA
  class ModelAliasRegistry
    DEFAULT_ALIASES = {
      # Short names
      "claude"     => "claude-sonnet-4-5",
      "sonnet"     => "claude-sonnet-4-5",
      "opus"       => "claude-opus-5",
      "haiku"      => "claude-haiku-4-5-20251001",
      "gpt4"       => "gpt-4o",
      "gpt4o"      => "gpt-4o",
      "gpt4mini"   => "gpt-4o-mini",
      "gemini"     => "gemini-3.8-flash",
      "flash"      => "gemini-3.8-flash",
      "llama"      => "meta-llama/llama-4-maverick",

      # Provider names (resolve to default model for provider)
      "anthropic"  => "claude-sonnet-4-5",
      "openai"     => "gpt-4o",
      "google"     => "gemini-3.8-flash",
      "meta"       => "meta-llama/llama-4-maverick",

      # Capability descriptors
      "fast"       => "claude-haiku-4-5-20251001",
      "cheap"      => "gpt-4o-mini",
      "best"       => "claude-opus-5",
      "coding"     => "claude-sonnet-4-5",
      "vision"     => "gpt-4o"
    }.freeze

    def initialize(custom_aliases = {})
      @aliases = DEFAULT_ALIASES.merge(normalize_keys(custom_aliases))
    end

    # Resolve a single name or alias to a model ID.
    #
    # @param name_or_alias [String] model name, alias, or capability descriptor
    # @return [String] resolved model ID
    def resolve(name_or_alias)
      normalized = normalize_key(name_or_alias)
      @aliases[normalized] || fuzzy_match(name_or_alias) || name_or_alias.to_s.strip
    end

    # Resolve a string containing multiple model references.
    # Handles comma-separated, "and"-separated, and mixed formats.
    #
    # @param input [String] e.g., "claude and gemini", "gpt4, llama"
    # @return [Array<String>] resolved model IDs
    def resolve_multiple(input)
      names = input.to_s.split(/\s*(?:,|and|&|\+)\s*/i)
      names.map { |n| resolve(n.strip) }.uniq
    end

    # Check if a name is a known alias
    #
    # @param name [String] the name to check
    # @return [Boolean]
    def known?(name)
      @aliases.key?(normalize_key(name))
    end

    # List all known aliases
    #
    # @return [Hash<String, String>]
    def all_aliases
      @aliases.dup
    end

    private

    def normalize_key(name)
      name.to_s.strip.downcase.gsub(/[-_\s]+/, '')
    end

    def normalize_keys(hash)
      hash.transform_keys { |k| normalize_key(k) }
    end

    def fuzzy_match(name)
      return nil unless defined?(RubyLLM) && RubyLLM.respond_to?(:models)

      target = name.to_s.downcase.strip
      return nil if target.empty?

      match = RubyLLM.models.find { |m| m.id.downcase.include?(target) }
      match&.id
    rescue StandardError
      nil
    end
  end
end
