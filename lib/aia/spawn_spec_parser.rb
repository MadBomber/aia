# frozen_string_literal: true

require_relative 'config/model_spec'

module AIA
  # Parses the explicit form of the /spawn and /add_recruit directives into a
  # spawn spec:
  #
  #   <name> <provider/model> <system prompt...>
  #
  # The second token is parsed as a model via {ModelSpec}, so
  # "ollama/qwen3.6:latest" yields model "qwen3.6:latest" + provider "ollama"
  # (and "lms/..." maps to the openai provider). Use "-" or "inherit" as the
  # model token to keep the parent robot's model and provider.
  #
  # Any token of the form "skill:<id>" (anywhere after the name) is pulled out
  # as a skill assignment and returned in :skills; "skill:a,b" lists several.
  # The skills become the robot's role (its system prompt) when recruited.
  class SpawnSpecParser
    INHERIT_TOKENS = %w[- inherit].freeze
    SKILL_TOKEN = /\Askill:(.+)\z/i

    # @param args [Array<String>] directive args (two or more expected)
    # @return [Hash] {name:, model:, provider:, system_prompt:, skills:}
    def self.parse(args)
      name = args[0]
      skills, rest = extract_skills(args[1..].to_a)
      model, provider = parse_model(rest[0])
      system_prompt = rest[1..].to_a.join(' ').strip
      system_prompt = nil if system_prompt.empty?

      { name: name, model: model, provider: provider, system_prompt: system_prompt, skills: skills }
    end

    # Split "skill:<id>" tokens out of the token list. Returns the collected
    # skill ids and the remaining (model + system-prompt) tokens, order intact.
    #
    # @param tokens [Array<String>]
    # @return [Array(Array<String>, Array<String>)] [skills, remaining]
    def self.extract_skills(tokens)
      skills = []
      remaining = tokens.reject do |token|
        match = token.match(SKILL_TOKEN)
        next false unless match

        skills.concat(match[1].split(',').map(&:strip).reject(&:empty?))
        true
      end
      [skills, remaining]
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
