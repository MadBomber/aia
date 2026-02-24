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
      If it can, output a JSON array of sub-task descriptions.
      If it cannot be meaningfully decomposed, output an empty array [].

      Rules:
      - Only decompose if sub-tasks are truly independent (can run in parallel)
      - Each sub-task should be self-contained
      - 2-5 sub-tasks maximum
      - Keep sub-task descriptions clear and specific

      Output ONLY valid JSON. No explanation.

      User request: %{prompt}
    PROMPT

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
    # @param prompt [String] the user's prompt
    # @return [Array<String>] array of sub-task descriptions (empty if not decomposable)
    def decompose(prompt)
      result = @robot.run(
        DECOMPOSITION_PROMPT % { prompt: prompt },
        mcp: :none, tools: :none
      )

      content = extract_content(result)
      subtasks = JSON.parse(content)

      subtasks.is_a?(Array) ? subtasks.select { |t| t.is_a?(String) && !t.empty? } : []
    rescue JSON::ParserError, StandardError
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

    # extract_content provided by ContentExtractor module
  end
end
