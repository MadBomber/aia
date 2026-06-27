# frozen_string_literal: true

# lib/aia/tools/recruit_robot_tool.rb
#
# RubyLLM::Tool that lets the crew chief grow its own crew. The chief can
# name a new robot, pick its provider/model (or inherit the chief's), and
# write its system prompt — all through standard tool-use protocol. The
# newcomer joins the running crew and answers to @name immediately.

module AIA
  class RecruitRobotTool < RubyLLM::Tool
    description "Recruit a new robot into the crew. Give it a name, an " \
                "optional provider/model (omit to inherit yours), optional " \
                "skills that define its role, and/or a system prompt. The " \
                "newcomer joins the crew right away and can be addressed with @name."

    param :name, type: :string, required: true,
          desc: "Unique name for the new robot, e.g. 'researcher'. Reserved: 'crew'."
    param :model, type: :string,
          desc: "Optional provider/model, e.g. 'ollama/qwen3.6:latest' or 'gpt-4o'. " \
                "Omit (or pass '-') to inherit the chief's model and provider."
    param :skills, type: :string,
          desc: "Optional comma-separated skill ids to assign as the robot's role " \
                "(e.g. 'security-review,ruby-style'). Each skill's content becomes " \
                "part of its system prompt. Use this to give crew members distinct jobs."
    param :system_prompt, type: :string,
          desc: "Optional extra system prompt, appended after any skills — its role, " \
                "persona, and instructions."

    def execute(name:, model: nil, skills: nil, system_prompt: nil)
      robot = AIA::Crew.recruit(build_spec(name, model, skills, system_prompt))
      "Recruited '#{robot.name}' into the crew on #{robot.model || 'the chief\'s model'}. " \
        "Address it with @#{robot.name}."
    rescue AIA::CrewError => e
      "Could not recruit '#{name}': #{e.message}"
    end

    private

    # Translate the tool's flat params into a Crew spec, splitting a
    # "provider/model" string into its parts (nil model => inherit the chief's)
    # and a comma-separated skills string into a list.
    def build_spec(name, model, skills, system_prompt)
      parsed_model, provider = SpawnSpecParser.parse_model(model)
      prompt = system_prompt.to_s.strip
      {
        name:          name,
        model:         parsed_model,
        provider:      provider,
        skills:        split_skills(skills),
        system_prompt: prompt.empty? ? nil : prompt
      }
    end

    # "security, ruby-style" => ["security", "ruby-style"]
    def split_skills(skills)
      skills.to_s.split(',').map(&:strip).reject(&:empty?)
    end
  end
end
