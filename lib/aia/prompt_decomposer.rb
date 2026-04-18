# frozen_string_literal: true

# lib/aia/prompt_decomposer.rb
#
# Decomposes complex prompts into independent sub-tasks.
# A coordinator robot breaks them down, specialist robots execute,
# and the coordinator reassembles.

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

    # JSON schema for the decomposition response.
    # Uses a wrapper object because Claude requires a top-level object (not a bare array).
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
    # Uses a temporary probe robot (not the main conversation robot) so the
    # decomposition analysis prompt and response do not pollute the main
    # conversation history. Falls back to [] if the model's output is not
    # parseable or the prompt cannot be meaningfully decomposed.
    #
    # @param prompt [String] the user's prompt
    # @return [Array<String>] array of sub-task descriptions (empty if not decomposable)
    def decompose(prompt)
      probe = build_probe_robot
      probe.with_schema(SUBTASKS_SCHEMA)
      result = probe.run(DECOMPOSITION_PROMPT % { prompt: prompt }, mcp: :none, tools: :none)
      subtasks = extract_subtasks(extract_content(result))
      subtasks.is_a?(Array) ? subtasks.select { |t| t.is_a?(String) && !t.empty? } : []
    rescue StandardError
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
    # with_schema causes ruby_llm to auto-parse the JSON into a Hash.
    # Falls back to text parsing for providers that ignore structured output.
    def extract_subtasks(content)
      case content
      when Hash
        content['subtasks'] || content[:subtasks] || []
      when Array
        content
      else
        []
      end
    end
  end
end
