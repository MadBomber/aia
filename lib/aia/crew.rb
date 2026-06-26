# frozen_string_literal: true

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
    # @param spec [Hash] {name:, model:, provider:, system_prompt:} (e.g. from SpawnSpecParser)
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
        system_prompt: spec[:system_prompt] || "You are #{name}.",
        local_tools:   chief_local_tools(chief),
        **model_opts(spec)
      )
      inherit_mcp(robot, chief)
      crew.add_robot(robot)
      robot
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
