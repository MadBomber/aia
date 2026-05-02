# frozen_string_literal: true

# lib/aia/prompt_decomposer.rb
#
# Decomposes complex prompts into independent sub-tasks.
# A coordinator robot breaks them down, specialist robots execute,
# and the coordinator reassembles.

require 'json'

module AIA
  class PromptDecomposer
    include ContentExtractor

    DECOMPOSITION_PROMPT = <<~PROMPT
      Analyze this user request and determine if it can be broken into independent sub-tasks.

      Rules:
      - Only decompose if sub-tasks are truly independent (can run in parallel)
      - Each sub-task should be self-contained
      - 2-5 sub-tasks maximum
      - Keep sub-task descriptions clear and specific
      - Use an empty subtasks array if the request cannot be meaningfully decomposed

      User request: %{prompt}
    PROMPT

    # Appended to DECOMPOSITION_PROMPT when the model does not support
    # structured output and with_schema cannot be used.
    FALLBACK_JSON_INSTRUCTION = <<~INSTRUCTION

      Respond with ONLY a JSON object — no explanation, no markdown, no prose:
      {"subtasks": ["sub-task description 1", "sub-task description 2"]}
    INSTRUCTION

    # JSON schema for structured-output-capable models.
    # Uses a wrapper object because Claude requires a top-level object.
    SUBTASKS_SCHEMA = {
      name: 'subtask_decomposition',
      schema: {
        type: 'object',
        properties: {
          subtasks: {
            type: 'array',
            items: { type: 'string' },
            description: 'Independent sub-task descriptions. Empty array if not decomposable.'
          }
        },
        required: ['subtasks'],
        additionalProperties: false
      },
      strict: true
    }.freeze

    SYNTHESIS_TEMPLATE = <<~PROMPT
      Original request: %{prompt}

      Sub-task results:
      %{results}

      Synthesize these results into a coherent final response that fully addresses the original request.
    PROMPT

    def initialize(robot)
      @robot = robot
    end

    # Attempt to decompose a prompt into sub-tasks.
    #
    # Uses a temporary probe robot so the decomposition prompt and response do
    # not pollute the main conversation history. When the configured model
    # supports structured output (structured_output? == true) with_schema is
    # used to get a guaranteed Hash back. Otherwise a JSON instruction is
    # appended to the prompt and the text response is parsed manually.
    #
    # @param prompt [String] the user's prompt
    # @return [Array<String>] sub-task descriptions (empty if not decomposable)
    def decompose(prompt)
      probe      = build_probe_robot
      use_schema = structured_output?

      if use_schema
        probe.with_schema(SUBTASKS_SCHEMA)
        full_prompt = DECOMPOSITION_PROMPT % { prompt: prompt }
      else
        AIA.logger.warn("PromptDecomposer: configured model does not support structured output — using JSON prompt fallback")
        full_prompt = (DECOMPOSITION_PROMPT + FALLBACK_JSON_INSTRUCTION) % { prompt: prompt }
      end

      result   = probe.run(full_prompt, mcp: :none, tools: :none)
      content  = extract_content(result)
      AIA.logger.debug("PromptDecomposer#decompose content class=#{content.class}")
      subtasks = extract_subtasks(content)
      subtasks.is_a?(Array) ? subtasks.select { |t| t.is_a?(String) && !t.empty? } : []
    rescue StandardError => e
      AIA.logger.warn("PromptDecomposer#decompose failed: #{e.class}: #{e.message}")
      []
    end

    # Synthesize sub-task results into a final response.
    #
    # @param prompt [String] the original user prompt
    # @param results [Array<String>] results from each sub-task
    # @return the synthesized response
    def synthesize(prompt, results)
      formatted_results = results.each_with_index.map do |r, i|
        "Sub-task #{i + 1}:\n#{r}"
      end.join("\n\n")

      @robot.run(
        SYNTHESIS_TEMPLATE % { prompt: prompt, results: formatted_results },
        mcp: :none, tools: :none
      )
    end

    private

    def structured_output?
      RubyLLM.models.find(AIA.config.models.first.name).structured_output?
    rescue StandardError
      false
    end

    # Build a fresh temporary robot for the decomposition probe.
    # This robot has no conversation history and is discarded after use,
    # keeping @robot's history clean for the normal or synthesis path.
    def build_probe_robot
      config     = AIA.config
      run_config = RobotFactory.build_run_config(config)
      RobotLab.build(
        name:          "decompose-probe",
        model:         config.models.first.name,
        system_prompt: nil,
        config:        run_config
      )
    end

    # Extract the subtasks array from the probe response.
    # Hash path: with_schema caused ruby_llm to auto-parse the JSON response.
    # String path: fallback text parsing for models without structured output.
    def extract_subtasks(content)
      case content
      when Hash
        content['subtasks'] || content[:subtasks] || []
      when Array
        content
      when String
        parsed = JSON.parse(content.gsub(/```(?:json)?\s*/i, '').gsub(/```/, '').strip)
        parsed.is_a?(Hash) ? parsed['subtasks'] || parsed[:subtasks] || [] : parsed
      else
        []
      end
    rescue JSON::ParserError
      []
    end
  end
end
