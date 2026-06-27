# frozen_string_literal: true

require_relative 'skill_utils'

module AIA
  # Runtime management of the chat session's crew — the Network behind
  # AIA.client. After RobotFactory wraps every session in a crew, members can be
  # added and removed mid-conversation. Both the user (via /add_recruit and
  # /drop_recruit) and a robot (via a tool) funnel through here.
  module Crew
    module_function

    # Recruit a new robot into the running crew. The newcomer is spawned from
    # the crew's chief (sharing its bus), optionally on an explicit
    # model/provider, then added to the crew so it shows in /robots and answers
    # to @name. With no model it inherits the chief's model and provider.
    #
    # @param spec [Hash] {name:, model:, provider:, system_prompt:, skills:} (e.g. from SpawnSpecParser)
    # @return [RobotLab::Robot] the recruited robot
    # @raise [AIA::CrewError]
    def recruit(spec)
      crew  = require_crew
      chief = crew.chief
      name  = spec[:name].to_s
      if name.casecmp?(MentionRouter::BROADCAST_TOKEN)
        raise CrewError, "'#{name}' is reserved (@crew broadcasts to every member)."
      end
      raise CrewError, "A crewmate named '#{name}' already exists." if member?(crew, name)

      robot = chief.spawn(
        name:          name,
        system_prompt: compose_system_prompt(spec),
        local_tools:   chief_local_tools(chief),
        **model_opts(spec)
      )
      inherit_mcp(robot, chief)
      crew.add_robot(robot)
      robot
    end

    # Reset an existing crewmate to a clean slate and re-skill it. The member is
    # dropped and re-recruited from the chief on the same model/provider, with a
    # fresh conversation and the given skills/system prompt as its new role. The
    # chief cannot be reskilled.
    #
    # @param name [String]
    # @param skills [Array<String>, nil] skill ids to assign as the new role
    # @param system_prompt [String, nil] extra system prompt appended after skills
    # @return [RobotLab::Robot] the re-skilled robot
    # @raise [AIA::CrewError]
    def reskill(name, skills: nil, system_prompt: nil)
      crew = require_crew
      name = name.to_s
      old  = find_member(crew, name)
      raise CrewError, "No crewmate named '#{name}'." unless old
      raise CrewError, "Cannot reskill the chief '#{name}'." if crew.chief&.name == name

      crew.remove_robot(name)
      recruit(
        name: name, model: old.model, provider: old.provider,
        skills: skills, system_prompt: system_prompt
      )
    end

    # Drop a crewmate by name. The chief (the session's lead robot) cannot be
    # dropped.
    #
    # @param name [String]
    # @return [RobotLab::Robot] the removed robot
    # @raise [AIA::CrewError]
    def drop(name)
      crew = require_crew
      name = name.to_s
      raise CrewError, "No crewmate named '#{name}'." unless member?(crew, name)
      raise CrewError, "Cannot drop the chief '#{name}'." if crew.chief&.name == name

      crew.remove_robot(name)
    end

    # The crew (Network) backing the current session.
    #
    # @return [RobotLab::Network]
    # @raise [AIA::CrewError] when the session isn't a crew
    def require_crew
      crew = AIA.client
      raise CrewError, "The active session is not a crew; cannot manage members." unless crew.respond_to?(:add_robot)

      crew
    end

    # @return [Boolean]
    def member?(crew, name)
      crew.crew.any? { |robot| robot.name == name }
    end

    # @return [RobotLab::Robot, nil]
    def find_member(crew, name)
      crew.crew.find { |robot| robot.name == name }
    end

    # Build the recruit's system prompt (its role) from any assigned skills
    # followed by an explicit system prompt. Falls back to a simple default when
    # neither is given.
    #
    # @return [String]
    def compose_system_prompt(spec)
      parts = [skills_prompt(spec[:skills]), spec[:system_prompt]].compact
      parts.empty? ? "You are #{spec[:name]}." : parts.join("\n\n")
    end

    # Load the bodies of the named skills, joined, to seed a recruit's role.
    # Raises so the caller (user or chief) hears about an unknown skill rather
    # than silently recruiting a robot without the role it was meant to have.
    #
    # @param skill_ids [Array<String>, nil]
    # @return [String, nil]
    # @raise [AIA::CrewError]
    def skills_prompt(skill_ids)
      ids = Array(skill_ids).map(&:to_s).reject(&:empty?)
      return nil if ids.empty?

      base = AIA::SkillUtils.skills_base_dir(AIA.config)
      raise CrewError, "No skills directory is configured." unless base

      missing = ids.reject { |id| AIA::SkillUtils.find_skill_dir(id, base) }
      raise CrewError, "Skill(s) not found: #{missing.join(', ')}." unless missing.empty?

      AIA::SkillUtils.load_skills_content(ids, base)
    end

    # Model/provider override for an explicit recruit. When a model is given the
    # provider is passed too (even nil) so it overrides the inherited chief
    # provider; with no model, {} lets the spawn inherit chief model + provider.
    #
    # @return [Hash]
    def model_opts(spec)
      return {} unless spec[:model]

      { model: spec[:model], provider: spec[:provider] }
    end

    # The chief's local tool instances, shared with the recruit so it can do the
    # same work (file/shell/etc.). Tool instances are effectively stateless, so
    # sharing them across crew members is safe.
    #
    # @return [Array]
    def chief_local_tools(chief)
      chief.respond_to?(:local_tools) ? Array(chief.local_tools) : []
    end

    # Hand the recruit the chief's already-connected MCP clients and tools rather
    # than opening fresh connections.
    #
    # @return [void]
    def inherit_mcp(robot, chief)
      return unless robot.respond_to?(:inject_mcp!) && chief.respond_to?(:mcp_clients)

      clients = chief.mcp_clients
      return if clients.nil? || clients.empty?

      robot.inject_mcp!(clients: clients, tools: Array(chief.mcp_tools))
    end
  end
end
