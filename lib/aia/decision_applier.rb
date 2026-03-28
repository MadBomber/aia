# frozen_string_literal: true

# lib/aia/decision_applier.rb
#
# Applies KBS decisions to the current turn execution context.
# Called by ChatLoop after evaluate_turn but before robot.run.
# Called by Session at startup before RobotFactory.build.
#
# Closes four gaps:
#   1. Model decisions influence which model handles the turn
#   2. MCP activation decisions filter which servers are used
#   3. Gate warnings are visible without --verbose
#   4. Learning signals feed into SessionTracker

module AIA
  class DecisionApplier
    AppliedContext = Struct.new(
      :model_overridden,    # Boolean — was a temp robot built for this turn?
      :temp_robot,          # RobotLab::Robot|nil — one-off robot for model override
      :mcp_filtered,        # Boolean — were MCP servers filtered?
      :tool_filtered,       # Boolean — were local tools filtered?
      :warnings_shown,      # Integer — count of gate warnings displayed
      :blocked,             # Boolean — was the turn blocked by a gate?
      keyword_init: true
    )

    def initialize(ui_presenter)
      @ui = ui_presenter
    end

    # Apply decisions and return what changed.
    #
    # @param decisions [AIA::Decisions]
    # @param config [AIA::Config, OpenStruct] the current configuration
    # @param startup [Boolean] true when called at session startup (permanent model change)
    # @return [AppliedContext]
    def apply(decisions, config, startup: false)
      context = AppliedContext.new(
        model_overridden: false,
        temp_robot: nil,
        mcp_filtered: false,
        tool_filtered: false,
        warnings_shown: 0,
        blocked: false
      )

      apply_gate_actions(decisions, context)
      return context if context.blocked

      if startup
        apply_startup_model_decision(decisions, config, context)
      else
        apply_turn_model_decision(decisions, config, context)
      end

      apply_mcp_filtering(decisions, context)
      apply_tool_filtering(decisions, context)
      persist_learning_signals(decisions)

      context
    end

    private

    # Gate warnings visible without --verbose; blocks stop the turn.
    def apply_gate_actions(decisions, context)
      decisions.gate_actions.each do |gate|
        case gate[:action]
        when "warn"
          @ui.display_warning(gate[:message])
          context.warnings_shown += 1
        when "block"
          @ui.display_error("Blocked: #{gate[:message]}")
          context.blocked = true
          return
        end
      end
    end

    # At startup: permanently change config.models so the robot is built
    # with the KBS-recommended model. No restore needed.
    def apply_startup_model_decision(decisions, config, context)
      recommended = decisions.recommended_model
      return unless recommended

      current = config.models.first
      current_name = current.respond_to?(:name) ? current.name : current.to_s
      return if recommended == current_name

      config.models = [AIA::ModelSpec.new(name: recommended)]
      context.model_overridden = true

      reason = decisions.model_decisions.first[:reason]
      @ui.display_info("[KBS] Startup model: #{recommended} (#{reason})")
    end

    # Per-turn: build a lightweight temp robot with the recommended model.
    # The temp robot has local tools but inherits MCP tools from the
    # primary robot to avoid expensive reconnections.
    def apply_turn_model_decision(decisions, config, context)
      recommended = decisions.recommended_model
      return unless recommended

      current = config.models.first
      current_name = current.respond_to?(:name) ? current.name : current.to_s
      return if recommended == current_name

      temp = build_temp_robot(recommended, config)
      if temp.nil?
        warn "[KBS] Failed to build temp robot for #{recommended} — using original robot"
        context.model_overridden = false
        return
      end

      context.temp_robot = temp
      context.model_overridden = true

      reason = decisions.model_decisions.first[:reason]
      @ui.display_info("[KBS] Using #{recommended} for this turn (#{reason})")
    end

    # MCP activation decisions filter which servers are active for this turn.
    # Sets TurnState so downstream code (RobotFactory, MCPDiscovery) can read it.
    def apply_mcp_filtering(decisions, context)
      activated = decisions.activated_mcp_servers
      return if activated.empty?

      AIA.turn_state.active_mcp_servers = activated
      context.mcp_filtered = true
    end

    # Tool activation decisions filter which local tools are active for this turn.
    # Sets TurnState so RobotFactory.filtered_tools can read it.
    def apply_tool_filtering(decisions, context)
      activated = decisions.activated_tools
      return if activated.empty?

      AIA.turn_state.active_tools = activated
      context.tool_filtered = true

      tool_names = activated.join(', ')
      @ui.display_info("[KBS] Tools for this turn: #{tool_names}")
    end

    # Learning signals recorded via SessionTracker for observability.
    def persist_learning_signals(decisions)
      return unless decisions.has_any?(:learning)

      tracker = AIA.session_tracker
      return unless tracker

      decisions.learnings.each do |learning|
        case learning[:signal]
        when "model_dissatisfaction"
          tracker.record_model_switch(
            from: learning[:model],
            to: "unknown",
            reason: "kbs_dissatisfaction"
          )
        when "model_success"
          tracker.record_user_feedback(satisfied: true)
        when "cost_update"
          logger.info("KBS learning: cost_update total=#{learning[:total]}")
        end
      end
    rescue StandardError => e
      logger.warn("Learning signal persistence failed: #{e.message}")
    end

    # Build a one-off robot with a different model for this turn.
    # Inherits local tools and MCP tools from the primary robot.
    def build_temp_robot(model_name, config)
      primary = AIA.client
      mcp_tools = primary.respond_to?(:mcp_tools) ? Array(primary.mcp_tools) : []

      robot = RobotLab.build(
        name:         "aia-kbs",
        system_prompt: SystemPromptAssembler.resolve_system_prompt(config),
        model:         model_name,
        local_tools:   ToolLoader.filtered_tools(config),
        config:        RobotFactory.build_run_config(config)
      )

      # Inherit MCP tools from the primary robot to avoid reconnection cost
      inject_mcp_tools(robot, mcp_tools) if mcp_tools.any?

      robot
    rescue StandardError => e
      logger.warn("KBS temp robot build failed: #{e.message}")
      nil
    end

    # Inject MCP tools from the primary robot into the temp robot.
    # RobotLab robots store MCP tools in @mcp_tools.
    def inject_mcp_tools(robot, mcp_tools)
      if robot.respond_to?(:mcp_tools=)
        robot.mcp_tools = mcp_tools
      elsif robot.instance_variable_defined?(:@mcp_tools)
        robot.instance_variable_set(:@mcp_tools, mcp_tools)
      end
    end
  end
end
