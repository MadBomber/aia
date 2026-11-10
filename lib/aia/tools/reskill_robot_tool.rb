# frozen_string_literal: true

# lib/aia/tools/reskill_robot_tool.rb
#
# RubyLLM::Tool that lets the crew chief reset one of its crew members to a
# clean slate and give it a different role. The member keeps its name and model
# but gets a fresh conversation and a new skill/system prompt — useful when a
# recruit drifted off task or needs to be repurposed for the next phase.

module AIA
  class ReskillRobotTool < RubyLLM::Tool
    description "Reset a crew member to a clean slate and re-skill it. The robot " \
                "keeps its @name and model but gets a fresh conversation and a new " \
                "role from the given skills and/or system prompt. Use this to " \
                "repurpose a member or recover one that went off task."

    parameter :name, type: :string, required: true,
              description: "Name of the existing crew member to reset (cannot be the chief)."
    parameter :skills, type: :string,
              description: "Optional comma-separated skill ids to assign as the new role " \
                           "(e.g. 'testing,performance')."
    parameter :system_prompt, type: :string,
              description: "Optional extra system prompt, appended after any skills."

    def execute(name:, skills: nil, system_prompt: nil)
      prompt = system_prompt.to_s.strip
      robot = AIA::Crew.reskill(
        name,
        skills:        AIA::SkillUtils.split_skills(skills),
        system_prompt: prompt.empty? ? nil : prompt
      )
      "Reset '#{robot.name}' to a clean slate with its new role. Address it with @#{robot.name}."
    rescue AIA::CrewError => e
      "Could not reskill '#{name}': #{e.message}"
    end
  end
end
