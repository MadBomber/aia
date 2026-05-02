# frozen_string_literal: true

# lib/aia/special_mode_handler.rb
#
# Handles special execution modes triggered by directives:
# /verify      — two independent answers + reconciliation
# /decompose   — break into parallel sub-tasks (Async::Barrier for I/O concurrency)
# /concurrent  — concurrent MCP server access
# /orchestrate — 3-tier layered orchestration (orchestrator → leads → specialists)

require 'async'

module AIA
  class SpecialModeHandler
    include ContentExtractor

    def initialize(robot:, ui_presenter:, tracker:)
      @robot        = robot
      @ui_presenter = ui_presenter
      @tracker      = tracker
      # Handlers are instantiated on first use to avoid loading their
      # dependencies (async, trakflow, etc.) unless the mode is invoked.
      @debate_handler       = nil
      @delegate_handler     = nil
      @spawn_handler        = nil
      @layered_orchestrator = nil
    end

    # Update the robot reference (e.g., after a model switch).
    def robot=(new_robot)
      @robot = new_robot
      @debate_handler&.robot       = new_robot
      @delegate_handler&.robot     = new_robot
      @spawn_handler&.robot        = new_robot
      @layered_orchestrator&.robot = new_robot
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
      require_relative 'verification_network'
      @ui_presenter.display_info("Running verification (2 independent + reconciliation)...")

      network = VerificationNetwork.build(AIA.config)
      result = @ui_presenter.with_spinner("Verifying") { network.run(message: prompt) }

      present_result(result, prompt: prompt, ui_presenter: @ui_presenter, tracker: @tracker)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Verification failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_decomposition(prompt)
      require_relative 'prompt_decomposer'
      total_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @ui_presenter.display_info("Decomposing prompt into sub-tasks...")
      decomposer    = PromptDecomposer.new(@robot)
      decompose_t0  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      subtasks      = decomposer.decompose(prompt)
      decompose_dur = Process.clock_gettime(Process::CLOCK_MONOTONIC) - decompose_t0

      if subtasks.empty?
        @ui_presenter.display_info("Prompt cannot be meaningfully decomposed. Running normally.")
        return false
      end

      @ui_presenter.display_info("Decomposed into #{subtasks.size} sub-tasks:")
      subtasks.each_with_index { |t, i| @ui_presenter.display_info("  #{i + 1}. #{t}") }

      timings         = Array.new(subtasks.size, 0.0)
      raw_subtasks    = Array.new(subtasks.size)
      wall_start      = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      results = Sync do
        barrier = Async::Barrier.new
        tasks = subtasks.each_with_index.map do |task, i|
          barrier.async do
            t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            @ui_presenter.display_info("Processing sub-task #{i + 1}...")
            r = if @robot.is_a?(RobotLab::Network)
                  @robot.run(message: task)
                else
                  @robot.run(task, mcp: :inherit, tools: :inherit)
                end
            timings[i]      = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
            raw_subtasks[i] = r
            extract_content(r)
          rescue => e
            timings[i] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
            @ui_presenter.display_info("  Sub-task #{i + 1} failed: #{e.message}")
            nil
          end
        end
        barrier.wait
        tasks.map(&:wait)
      end

      parallel_wall    = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall_start
      serial_est       = timings.sum
      parallel_speedup = serial_est / parallel_wall

      raise DecomposeError, "All sub-tasks failed" if results.all?(&:nil?)

      @ui_presenter.display_info("Synthesizing results...")
      synth_t0  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      final     = decomposer.synthesize(prompt, results.compact)
      synth_dur = Process.clock_gettime(Process::CLOCK_MONOTONIC) - synth_t0

      total_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - total_start

      lines = ["", "Benchmark:"]
      lines << "  Decompose probe : #{format('%.2f', decompose_dur)}s"
      timings.each_with_index { |t, i| lines << "  Sub-task #{i + 1}      : #{format('%.2f', t)}s" }
      lines << "  Synthesis       : #{format('%.2f', synth_dur)}s"
      lines << "  ─────────────────────────────────────────"
      lines << "  Sub-tasks serial est. : #{format('%.2f', serial_est)}s  (sum of sub-task times)"
      lines << "  Sub-tasks concurrent  : #{format('%.2f', parallel_wall)}s  (#{format('%.1f', parallel_speedup)}x parallel speedup)"
      lines << "  Total flow wall time  : #{format('%.2f', total_wall)}s  (compare against --tokens Time for a normal run)"
      @ui_presenter.display_info(lines.join("\n"))

      display_decompose_token_metrics(raw_subtasks, final, total_wall)

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
      result = @ui_presenter.with_spinner("Processing (concurrent)") { network.run(message: prompt) }
      content = extract_content(result)

      present_result(result, prompt: prompt, ui_presenter: @ui_presenter, tracker: @tracker)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Concurrent MCP failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_debate(prompt)
      content = debate_handler.handle(HandlerContext.new(prompt: prompt))
      return false unless content

      display_and_save(content)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Debate failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_delegation(prompt)
      content = delegate_handler.handle(HandlerContext.new(prompt: prompt))
      return false unless content

      display_and_save(content)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Delegation failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_spawn(prompt, specialist_type: nil)
      content = spawn_handler.handle(HandlerContext.new(prompt: prompt, specialist_type: specialist_type))
      return false unless content

      display_and_save(content)
      true
    rescue StandardError => e
      @ui_presenter.display_info("Spawn failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_orchestration(prompt)
      @ui_presenter.display_info("Starting 3-tier layered orchestration...")

      content = layered_orchestrator.handle(HandlerContext.new(robot: @robot, prompt: prompt))

      if content
        display_and_save(content)
      else
        @ui_presenter.display_separator
      end

      true  # always consume the prompt; never fall through to normal mode
    rescue StandardError => e
      @ui_presenter.display_info("Orchestration failed: #{e.class}: #{e.message}")
      @ui_presenter.display_separator
      true
    end

    def debate_handler
      @debate_handler ||= begin
        require_relative 'debate_handler'
        DebateHandler.new(robot: @robot, ui_presenter: @ui_presenter, tracker: @tracker)
      end
    end

    def delegate_handler
      @delegate_handler ||= begin
        require_relative 'delegate_handler'
        require_relative 'task_decomposer'
        require_relative 'task_executor'
        DelegateHandler.new(
          robot: @robot, ui_presenter: @ui_presenter,
          tracker: @tracker, task_coordinator: AIA.task_coordinator
        )
      end
    end

    def spawn_handler
      @spawn_handler ||= begin
        require_relative 'spawn_handler'
        SpawnHandler.new(robot: @robot, ui_presenter: @ui_presenter, tracker: @tracker)
      end
    end

    def layered_orchestrator
      @layered_orchestrator ||= begin
        require_relative 'layered_orchestrator'
        LayeredOrchestrator.new(robot: @robot, ui_presenter: @ui_presenter, tracker: @tracker)
      end
    end

    # Display content, write to output file, and print separator.
    # Used by handlers that receive pre-extracted content from sub-handlers.
    def display_and_save(content)
      @ui_presenter.display_ai_response(content)
      output_to_file(content)
      @ui_presenter.display_separator
    end

    # Aggregate token counts from all sub-task raw results plus the synthesis
    # result and display a combined metrics table. Only runs when --tokens is set.
    def display_decompose_token_metrics(raw_subtasks, synthesis_result, total_elapsed)
      return unless AIA.config.flags.tokens

      total_input  = 0
      total_output = 0

      raw_subtasks.compact.each do |r|
        raw = r.respond_to?(:raw) ? r.raw : nil
        next unless raw&.respond_to?(:input_tokens) && raw.input_tokens
        total_input  += raw.input_tokens  || 0
        total_output += raw.output_tokens || 0
      end

      synth_raw = synthesis_result.respond_to?(:raw) ? synthesis_result.raw : nil
      if synth_raw&.respond_to?(:input_tokens) && synth_raw.input_tokens
        total_input  += synth_raw.input_tokens  || 0
        total_output += synth_raw.output_tokens || 0
      end

      return if total_input.zero? && total_output.zero?

      @ui_presenter.display_token_metrics({
        model_id:      AIA.config.models.first.name,
        input_tokens:  total_input,
        output_tokens: total_output,
        elapsed:       total_elapsed
      })
    end

  end
end
