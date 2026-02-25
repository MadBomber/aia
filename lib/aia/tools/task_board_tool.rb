# frozen_string_literal: true

# lib/aia/tools/task_board_tool.rb
#
# RubyLLM::Tool that lets robots manage a shared TrakFlow task board.
# Robots can create tasks for each other, check what's ready, claim
# work, and report completion — all through standard tool-use protocol.

require "json"

module AIA
  class TaskBoardTool < RubyLLM::Tool
    description "Manage a shared task board. Create tasks for other robots, " \
                "check what's ready, claim tasks, and report completion."

    param :action, type: :string, required: true,
          desc: "One of: create, plan, ready, claim, complete, block, status"
    param :title, type: :string,
          desc: "Task title (for create/plan actions)"
    param :assignee, type: :string,
          desc: "Robot name to assign to (for create/claim/ready)"
    param :labels, type: :string,
          desc: "Comma-separated labels (for create)"
    param :blocked_by, type: :string,
          desc: "Comma-separated blocker task IDs (for create)"
    param :steps, type: :string,
          desc: "JSON array of step objects [{title:, assignee:}] (for plan)"
    param :task_id, type: :string,
          desc: "Task ID (for claim/complete/block)"
    param :result, type: :string,
          desc: "Result summary (for complete) or reason (for block)"

    def execute(action:, **params)
      coordinator = AIA.task_coordinator
      return "Task board unavailable (TrakFlow not initialized)" unless coordinator&.available?

      robot_name = params[:_robot_name] || "unknown"

      case action
      when "create"  then execute_create(coordinator, robot_name, params)
      when "plan"    then execute_plan(coordinator, robot_name, params)
      when "ready"   then execute_ready(coordinator, params)
      when "claim"   then execute_claim(coordinator, robot_name, params)
      when "complete" then execute_complete(coordinator, robot_name, params)
      when "block"   then execute_block(coordinator, robot_name, params)
      when "status"  then coordinator.status_summary || "No tasks"
      else
        "Unknown action: #{action}. Use: create, plan, ready, claim, complete, block, status"
      end
    end

    private

    def execute_create(coordinator, robot_name, params)
      task = coordinator.create_task(
        params[:title],
        assignee:   params[:assignee],
        labels:     parse_csv(params[:labels]),
        blocked_by: parse_csv(params[:blocked_by]),
        creator:    robot_name
      )
      task ? "Created [#{task.id}] '#{task.title}'" : "Failed to create task"
    end

    def execute_plan(coordinator, robot_name, params)
      steps = JSON.parse(params[:steps] || "[]", symbolize_names: true)
      result = coordinator.create_plan(
        params[:title], steps: steps, creator: robot_name
      )
      result ? "Plan created with #{result[:steps].size} steps" : "Failed to create plan"
    rescue JSON::ParserError => e
      "Invalid steps JSON: #{e.message}"
    end

    def execute_ready(coordinator, params)
      tasks = coordinator.ready_tasks(robot_name: params[:assignee])
      return "No ready tasks" if tasks.empty?
      tasks.map { |t| "[#{t.id}] #{t.title} (#{t.assignee || 'unassigned'})" }.join("\n")
    end

    def execute_claim(coordinator, robot_name, params)
      coordinator.claim_task(params[:task_id], robot_name)
      "Claimed task #{params[:task_id]}"
    end

    def execute_complete(coordinator, robot_name, params)
      coordinator.complete_task(
        params[:task_id],
        result:     params[:result] || "Done",
        robot_name: robot_name
      )
      "Completed task #{params[:task_id]}"
    end

    def execute_block(coordinator, robot_name, params)
      coordinator.block_task(
        params[:task_id],
        reason:     params[:result] || "Blocked",
        robot_name: robot_name
      )
      "Blocked task #{params[:task_id]}"
    end

    def parse_csv(value)
      (value || "").split(",").map(&:strip).reject(&:empty?)
    end
  end
end
