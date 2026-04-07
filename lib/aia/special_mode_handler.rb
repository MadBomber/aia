# frozen_string_literal: true

# lib/aia/special_mode_handler.rb
#
# Handles special execution modes triggered by directives:
# /verify      — two independent answers + reconciliation
# /decompose   — break into parallel sub-tasks
# /concurrent  — concurrent MCP server access
# /orchestrate — 3-tier layered orchestration (orchestrator → leads → specialists)

module AIA
  class SpecialModeHandler
    include ContentExtractor

    def initialize(robot:, ui_presenter:, tracker:)
      @robot = robot
      @ui_presenter = ui_presenter
      @tracker = tracker

      @debate_handler = DebateHandler.new(
        robot: @robot, ui_presenter: @ui_presenter, tracker: @tracker
      )
      @delegate_handler = DelegateHandler.new(
        robot: @robot, ui_presenter: @ui_presenter,
        tracker: @tracker, task_coordinator: AIA.task_coordinator
      )
      @spawn_handler = SpawnHandler.new(
        robot: @robot, ui_presenter: @ui_presenter, tracker: @tracker
      )
      @layered_orchestrator = LayeredOrchestrator.new(
        robot: @robot, ui_presenter: @ui_presenter, tracker: @tracker
      )
    end

    # Update the robot reference (e.g., after a model switch).
    def robot=(new_robot)
      @robot = new_robot
      @debate_handler.robot       = new_robot
      @delegate_handler.robot     = new_robot
      @spawn_handler.robot        = new_robot
      @layered_orchestrator.robot = new_robot
    end

    # Check TurnState flags and dispatch to the appropriate handler.
    # Returns true if a special mode was handled.
    #
    # @param prompt [String] the user prompt
    # @return [Boolean]
    def handle(prompt)
      turn_state = AIA.turn_state

      if turn_state.force_verify
        turn_state.force_verify = false
        return handle_verification(prompt)
      end

      if turn_state.force_decompose
        turn_state.force_decompose = false
        return handle_decomposition(prompt)
      end

      if turn_state.force_concurrent_mcp
        turn_state.force_concurrent_mcp = false
        return handle_concurrent_mcp(prompt)
      end

      if turn_state.force_debate
        turn_state.force_debate = false
        return handle_debate(prompt)
      end

      if turn_state.force_delegate
        turn_state.force_delegate = false
        return handle_delegation(prompt)
      end

      if turn_state.force_spawn
        turn_state.force_spawn = false
        type = turn_state.spawn_type
        turn_state.spawn_type = nil
        return handle_spawn(prompt, specialist_type: type)
      end

      if turn_state.force_orchestrate
        turn_state.force_orchestrate = false
        return handle_orchestration(prompt)
      end

      false
    end

    private

    def handle_verification(prompt)
      @ui_presenter.display_info("Running verification (2 independent + reconciliation)...")

      network = VerificationNetwork.build(AIA.config)
      result = @ui_presenter.with_spinner("Verifying") { network.run(prompt) }

      present_result(result, prompt: prompt, ui_presenter: @ui_presenter, tracker: @tracker)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Verification failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_decomposition(prompt)
      @ui_presenter.display_info("Decomposing prompt into sub-tasks...")

      decomposer = PromptDecomposer.new(@robot)
      subtasks = decomposer.decompose(prompt)

      if subtasks.empty?
        @ui_presenter.display_info("Prompt cannot be meaningfully decomposed. Running normally.")
        return false
      end

      @ui_presenter.display_info("Decomposed into #{subtasks.size} sub-tasks:")
      subtasks.each_with_index { |t, i| @ui_presenter.display_info("  #{i + 1}. #{t}") }

      results = subtasks.map.with_index do |task, i|
        @ui_presenter.display_info("Processing sub-task #{i + 1}...")
        r = if @robot.is_a?(RobotLab::Network)
              @robot.run(message: task)
            else
              @robot.run(task, mcp: :inherit, tools: :inherit)
            end
        extract_content(r)
      end

      @ui_presenter.display_info("Synthesizing results...")
      final = decomposer.synthesize(prompt, results)
      content = extract_content(final)

      present_result(final, prompt: prompt, ui_presenter: @ui_presenter, tracker: @tracker)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Decomposition failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_concurrent_mcp(prompt)
      return false unless (AIA.config.mcp_servers || []).size > 1

      discovery = MCPDiscovery.new
      relevant = discovery.discover(AIA.config)
      return false if relevant.size <= 1

      grouper = MCPGrouper.new
      groups = grouper.group(relevant)
      return false if groups.size < 2

      @ui_presenter.display_info("Running concurrent MCP across #{groups.size} server groups...")

      network = RobotFactory.build_concurrent_mcp_network(AIA.config, groups)
      result = @ui_presenter.with_spinner("Processing (concurrent)") { network.run(prompt) }
      content = extract_content(result)

      present_result(result, prompt: prompt, ui_presenter: @ui_presenter, tracker: @tracker)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Concurrent MCP failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_debate(prompt)
      content = @debate_handler.handle(HandlerContext.new(prompt: prompt))
      return false unless content

      display_and_save(content)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Debate failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_delegation(prompt)
      content = @delegate_handler.handle(HandlerContext.new(prompt: prompt))
      return false unless content

      display_and_save(content)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Delegation failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_spawn(prompt, specialist_type: nil)
      content = @spawn_handler.handle(HandlerContext.new(prompt: prompt, specialist_type: specialist_type))
      return false unless content

      display_and_save(content)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Spawn failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_orchestration(prompt)
      @ui_presenter.display_info("Starting 3-tier layered orchestration...")

      content = @layered_orchestrator.handle(HandlerContext.new(robot: @robot, prompt: prompt))
      return false unless content

      display_and_save(content)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Orchestration failed: #{e.class}: #{e.message}")
      false
    end

    # Display content, write to output file, and print separator.
    # Used by handlers that receive pre-extracted content from sub-handlers.
    def display_and_save(content)
      @ui_presenter.display_ai_response(content)
      output_to_file(content)
      @ui_presenter.display_separator
    end

  end
end
