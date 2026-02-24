# frozen_string_literal: true

# lib/aia/trakflow_bridge.rb
#
# Bridge between AIA and TrakFlow's MCP interface.
# TrakFlow is a distributed task tracking system for AI agents.
# It manages plans, workflows, tasks, and dependencies.

module AIA
  class TrakFlowBridge
    def initialize(robot)
      @robot = robot
    end

    # Check if TrakFlow MCP server is available.
    #
    # @return [Boolean]
    def available?
      return false unless @robot

      if @robot.respond_to?(:mcp_servers)
        Array(@robot.mcp_servers).any? { |s| server_name(s) == "trak_flow" }
      elsif @robot.respond_to?(:mcp_tools)
        Array(@robot.mcp_tools).any? { |t| t_name = t.respond_to?(:name) ? t.name : t.to_s; t_name.include?("trak_flow") }
      else
        false
      end
    rescue StandardError
      false
    end

    # Create a TrakFlow plan from a pipeline of prompt IDs.
    #
    # @param pipeline [Array<String>] prompt IDs in pipeline order
    # @return [String, nil] plan creation result
    def create_plan_from_pipeline(pipeline)
      return nil unless available?

      steps = pipeline.map.with_index { |p, i| "Step #{i + 1}: #{p}" }.join(', ')
      plan_name = "Pipeline: #{pipeline.join(' → ')}"

      run_trakflow_command(
        "Create a TrakFlow plan named '#{plan_name}' with these sequential steps: #{steps}. " \
        "Each step should block the next one."
      )
    end

    # Update a task's status in TrakFlow.
    #
    # @param step_name [String] task/step name
    # @param status [Symbol] :started, :completed, or :failed
    # @param reason [String, nil] reason for failure (when status is :failed)
    def update_step_status(step_name, status, reason: nil)
      return unless available?

      case status
      when :started
        run_trakflow_command("Start TrakFlow task '#{step_name}'")
      when :completed
        run_trakflow_command("Close TrakFlow task '#{step_name}'")
      when :failed
        msg = "Block TrakFlow task '#{step_name}'"
        msg += " with reason: #{reason}" if reason
        run_trakflow_command(msg)
      end
    end

    # Check for ready tasks (tasks with no open blockers).
    #
    # @return [String, nil] description of ready tasks
    def check_ready_tasks
      return nil unless available?
      run_trakflow_command("List all ready TrakFlow tasks (tasks with no open blockers)")
    end

    # Get a summary of the current TrakFlow project state.
    #
    # @return [String, nil] project summary
    def project_summary
      return nil unless available?
      run_trakflow_command("Show TrakFlow project summary including task counts and status")
    end

    # Create a task in TrakFlow.
    #
    # @param title [String] task title
    # @param description [String, nil] task description
    # @param labels [Array<String>] labels in dimension:value format
    # @return [String, nil] task creation result
    def create_task(title, description: nil, labels: [])
      return nil unless available?

      cmd = "Create a TrakFlow task titled '#{title}'"
      cmd += " with description: #{description}" if description
      cmd += " with labels: #{labels.join(', ')}" if labels.any?

      run_trakflow_command(cmd)
    end

    private

    def run_trakflow_command(prompt)
      result = @robot.run(prompt, mcp: :inherit, tools: :none)
      extract_content(result)
    rescue StandardError => e
      warn "Warning: TrakFlow command failed: #{e.message}"
      nil
    end

    def extract_content(result)
      if result.respond_to?(:reply)
        result.reply
      elsif result.respond_to?(:content)
        result.content
      else
        result.to_s
      end
    end

    def server_name(server)
      if server.respond_to?(:name)
        server.name
      elsif server.is_a?(Hash)
        server[:name] || server["name"]
      else
        server.to_s
      end
    end
  end
end
