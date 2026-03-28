# frozen_string_literal: true

# lib/aia/task_coordinator.rb
#
# Bridges robots and TrakFlow task management.
# Robots use this to create tasks for each other, claim work,
# and report completion. Wraps TrakFlow's database API in a
# robot-friendly interface.

module AIA
  class TaskCoordinator
    def initialize(bridge: TrakFlowBridge.new)
      @bridge = bridge
      @db     = bridge.db
    end

    def available?
      @bridge.available?
    end

    # Clear all tasks from the board for a fresh session.
    def clear!
      return unless available?
      @db.clear!
    end

    # A robot creates a task for another robot (or any robot) to handle.
    #
    # @param title [String] task description
    # @param assignee [String, nil] target robot name, nil = any robot
    # @param parent_id [String, nil] parent task for hierarchy
    # @param blocked_by [Array<String>] task IDs that must complete first
    # @param labels [Array<String>] labels like "robot:alice", "domain:code"
    # @param creator [String] name of the creating robot
    # @return [TrakFlow::Models::Task, nil]
    def create_task(title, assignee: nil, parent_id: nil,
                    blocked_by: [], labels: [], creator: "aia")
      return nil unless available?

      task = TrakFlow::Models::Task.new(
        title: title, assignee: assignee, type: "task"
      )
      task = @db.create_task(task)

      @db.add_label(TrakFlow::Models::Label.new(
        task_id: task.id, name: "creator:#{creator}"
      ))

      labels.each do |label|
        @db.add_label(TrakFlow::Models::Label.new(
          task_id: task.id, name: label
        ))
      end

      blocked_by.each do |blocker_id|
        @db.add_dependency(TrakFlow::Models::Dependency.new(
          source_id: blocker_id, target_id: task.id, type: "blocks"
        ))
      end

      if parent_id
        @db.add_dependency(TrakFlow::Models::Dependency.new(
          source_id: parent_id, target_id: task.id, type: "parent-child"
        ))
      end

      task
    end

    # A robot creates a full plan (blueprint) with ordered steps.
    #
    # @param title [String] plan title
    # @param steps [Array<Hash>] each: { title:, assignee:, labels: [] }
    # @param creator [String] creating robot name
    # @param ephemeral [Boolean] true for single-session plans (auto-gc)
    # @return [Hash, nil] { plan:, steps: }
    def create_plan(title, steps:, creator: "aia", ephemeral: false)
      return nil unless available?

      plan = TrakFlow::Models::Task.new(
        title: title, plan: true, type: "task"
      )
      plan = @db.create_task(plan)

      @db.add_label(TrakFlow::Models::Label.new(
        task_id: plan.id, name: "creator:#{creator}"
      ))

      prev_step = nil
      step_tasks = steps.map.with_index do |step_def, _i|
        step = @db.create_child_task(plan.id, {
          title:    step_def[:title],
          assignee: step_def[:assignee],
          type:     "task"
        })

        Array(step_def[:labels]).each do |label|
          @db.add_label(TrakFlow::Models::Label.new(
            task_id: step.id, name: label
          ))
        end

        if prev_step
          @db.add_dependency(TrakFlow::Models::Dependency.new(
            source_id: prev_step.id, target_id: step.id, type: "blocks"
          ))
        end

        prev_step = step
        step
      end

      { plan: plan, steps: step_tasks }
    end

    # Get ready tasks, optionally filtered by assignee.
    #
    # @param robot_name [String, nil] filter by assignee
    # @return [Array<TrakFlow::Models::Task>]
    def ready_tasks(robot_name: nil)
      return [] unless available?

      tasks = @db.ready_tasks
      robot_name ? tasks.select { |t| t.assignee == robot_name } : tasks
    end

    # A robot claims a task (sets in_progress with its name).
    #
    # @param task_id [String]
    # @param robot_name [String]
    def claim_task(task_id, robot_name)
      return unless available?

      task = @db.find_task(task_id)
      return unless task

      task.status   = "in_progress"
      task.assignee = robot_name
      task.append_trace("claimed", "Claimed by #{robot_name}")
      @db.update_task(task)
    end

    # A robot completes a task with a result summary.
    #
    # @param task_id [String]
    # @param result [String] summary of what was done
    # @param robot_name [String]
    def complete_task(task_id, result:, robot_name:)
      return unless available?

      task = @db.find_task(task_id)
      return unless task

      task.close!(reason: result)
      @db.add_comment(TrakFlow::Models::Comment.new(
        task_id: task_id, author: robot_name, body: result
      ))
      @db.update_task(task)
    end

    # A robot marks a task as blocked with a reason.
    #
    # @param task_id [String]
    # @param reason [String]
    # @param robot_name [String]
    def block_task(task_id, reason:, robot_name:)
      return unless available?

      task = @db.find_task(task_id)
      return unless task

      task.status = "blocked"
      task.append_trace("blocked", "#{robot_name}: #{reason}")
      @db.update_task(task)
    end

    # Summary of the current task board state.
    #
    # @return [String, nil]
    def status_summary
      return nil unless available?

      all     = @db.list_tasks({})
      ready   = @db.ready_tasks
      blocked = @db.blocked_tasks

      by_assignee = all.select(&:assignee).group_by(&:assignee)

      lines = ["Task Board (#{all.size} total, #{ready.size} ready, #{blocked.size} blocked):"]
      by_assignee.sort.each do |assignee, tasks|
        open_count   = tasks.count { |t| t.open? || t.in_progress? }
        closed_count = tasks.count(&:closed?)
        lines << "  #{assignee}: #{open_count} open, #{closed_count} done"
      end

      unassigned = all.reject(&:assignee)
      lines << "  unassigned: #{unassigned.size}" unless unassigned.empty?

      lines.join("\n")
    end
  end
end
