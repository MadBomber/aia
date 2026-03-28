# frozen_string_literal: true

# lib/aia/task_decomposer.rb
#
# Extracts plan decomposition logic from DelegateHandler.
# The lead robot analyzes a prompt and breaks it into subtasks
# with robot assignments.

require "json"

module AIA
  class TaskDecomposer
    include ContentExtractor

    def initialize(lead_robot:, ui_presenter:)
      @lead = lead_robot
      @ui   = ui_presenter
    end

    # Decompose a prompt into subtasks assigned to specific robots.
    #
    # @param prompt [String] the original user prompt
    # @param robot_names [Array<String>] available robot names
    # @return [Array<Hash>] steps with :title and :assignee, or [] on failure
    def decompose(prompt, robot_names)
      @ui.display_info("#{@lead.name} analyzing and delegating...")

      plan_result = @lead.run(<<~PROMPT, mcp: :none, tools: :none)
        Break this request into subtasks. Assign each to the most
        appropriate team member based on their model capabilities.

        Team: #{robot_names.join(', ')}
        Request: #{prompt}

        Respond with ONLY a JSON array:
        [{"title": "subtask description", "assignee": "robot_name"}]
      PROMPT

      reply = extract_content(plan_result)
      parse_plan(reply, robot_names)
    end

    private

    def parse_plan(json_text, valid_names)
      match = json_text.to_s.match(/\[.*\]/m)
      return [] unless match

      JSON.parse(match[0], symbolize_names: true).map do |step|
        assignee = valid_names.include?(step[:assignee]) ? step[:assignee] : valid_names.first
        { title: step[:title].to_s, assignee: assignee }
      end
    rescue JSON::ParserError
      []
    end
  end
end
