# frozen_string_literal: true

# lib/aia/trakflow_bridge.rb
#
# Bridge between AIA and TrakFlow task tracking.
# Uses the trak_flow gem directly as a Ruby library —
# no MCP server or LLM intermediation needed.

require "trak_flow"

module AIA
  class TrakFlowBridge
    def initialize
      @db = connect_database
    end

    # Whether a TrakFlow project is initialized and the database is accessible.
    #
    # @return [Boolean]
    def available?
      !@db.nil?
    end

    # Create a TrakFlow plan from a pipeline of prompt IDs.
    # Each step blocks the next, enforcing sequential execution.
    #
    # @param pipeline [Array<String>] prompt IDs in pipeline order
    # @return [String, nil] summary of created plan
    def create_plan_from_pipeline(pipeline)
      return nil unless available?

      plan_title = "Pipeline: #{pipeline.join(' → ')}"
      plan = TrakFlow::Models::Task.new(title: plan_title, plan: true, type: "task")
      plan = @db.create_task(plan)

      prev_step = nil
      pipeline.each_with_index do |prompt_id, i|
        step = @db.create_child_task(plan.id, {
          title: "Step #{i + 1}: #{prompt_id}",
          type:  "task"
        })

        if prev_step
          @db.add_dependency(TrakFlow::Models::Dependency.new(
            source_id: prev_step.id,
            target_id: step.id,
            type:      "blocks"
          ))
        end

        prev_step = step
      end

      "Plan '#{plan_title}' created with #{pipeline.size} steps."
    rescue StandardError => e
      warn "Warning: TrakFlow plan creation failed: #{e.message}"
      nil
    end

    # Update a task's status in TrakFlow.
    #
    # @param step_name [String] task title to find
    # @param status [Symbol] :started, :completed, or :failed
    # @param reason [String, nil] reason for failure
    def update_step_status(step_name, status, reason: nil)
      return unless available?

      task = find_task_by_title(step_name)
      return unless task

      case status
      when :started
        task.status = "in_progress"
        @db.update_task(task)
      when :completed
        task.close!(reason: reason || "Completed")
        @db.update_task(task)
      when :failed
        task.status = "blocked"
        task.append_trace("blocked", reason) if reason
        @db.update_task(task)
      end
    rescue StandardError => e
      warn "Warning: TrakFlow status update failed: #{e.message}"
    end

    # List ready tasks (tasks with no open blockers).
    #
    # @return [String, nil] formatted list of ready tasks
    def check_ready_tasks
      return nil unless available?

      tasks = @db.ready_tasks
      return nil if tasks.empty?

      lines = tasks.map { |t| "  - [#{t.id}] #{t.title} (#{t.status})" }
      "Ready tasks (#{tasks.size}):\n#{lines.join("\n")}"
    rescue StandardError => e
      warn "Warning: TrakFlow ready tasks query failed: #{e.message}"
      nil
    end

    # Get a summary of the current TrakFlow project state.
    #
    # @return [String, nil] project summary
    def project_summary
      return nil unless available?

      all = @db.list_tasks({})
      by_status = all.group_by(&:status)

      lines = ["TrakFlow Project Summary (#{all.size} tasks):"]
      by_status.sort.each do |status, tasks|
        lines << "  #{status}: #{tasks.size}"
      end

      ready = @db.ready_tasks
      lines << "  ready (unblocked): #{ready.size}" unless ready.empty?

      lines.join("\n")
    rescue StandardError => e
      warn "Warning: TrakFlow summary failed: #{e.message}"
      nil
    end

    # Create a task in TrakFlow.
    #
    # @param title [String] task title
    # @param description [String, nil] task description
    # @param labels [Array<String>] labels to attach
    # @return [String, nil] confirmation message
    def create_task(title, description: nil, labels: [])
      return nil unless available?

      task = TrakFlow::Models::Task.new(
        title:       title,
        description: description,
        type:        "task"
      )
      task = @db.create_task(task)

      labels.each do |label_name|
        @db.add_label(TrakFlow::Models::Label.new(task_id: task.id, name: label_name))
      end

      "Task created: [#{task.id}] #{title}"
    rescue StandardError => e
      warn "Warning: TrakFlow task creation failed: #{e.message}"
      nil
    end

    attr_reader :db

    private

    # Connect to the TrakFlow database if a project is initialized.
    def connect_database
      return nil unless TrakFlow.initialized?

      db = TrakFlow::Storage::Database.new(TrakFlow.database_path)
      db.connect
      db
    rescue StandardError
      nil
    end

    # Find a task by its title (partial match).
    def find_task_by_title(title)
      tasks = @db.list_tasks(title: title)
      tasks.first
    end
  end
end
