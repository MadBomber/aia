# frozen_string_literal: true

# lib/aia/delegate_handler.rb
#
# Lead robot analyzes a prompt, creates a TrakFlow plan with steps
# assigned to specific robots, then each robot executes its tasks
# in dependency order. Combines TypedBus, SharedMemory, and TrakFlow.
#
# Decomposition is delegated to TaskDecomposer.
# Step execution is delegated to TaskExecutor.

module AIA
  class DelegateHandler
    include ContentExtractor
    include HandlerProtocol

    def initialize(robot:, ui_presenter:, tracker:, task_coordinator:)
      @robot            = robot
      @ui_presenter     = ui_presenter
      @tracker          = tracker
      @task_coordinator = task_coordinator
    end

    attr_writer :robot

    # Decompose a prompt into subtasks, assign to robots, and execute.
    #
    # @param context [HandlerContext] — reads context.prompt
    # @return [String, nil] combined results, or nil if not applicable
    def handle(context)
      prompt = context.prompt
      return nil unless @robot.is_a?(RobotLab::Network)
      return nil unless @task_coordinator&.available?

      robots      = @robot.robots
      robot_names = robots.values.map(&:name)
      lead        = robots.values.first

      # Step 1: Decompose the work
      decomposer = TaskDecomposer.new(lead_robot: lead, ui_presenter: @ui_presenter)
      steps = decomposer.decompose(prompt, robot_names)

      if steps.empty?
        @ui_presenter.display_info("Could not decompose into subtasks.")
        return nil
      end

      # Step 2: Create TrakFlow plan
      plan = @task_coordinator.create_plan(
        "Delegated: #{prompt[0, 60]}",
        steps: steps, creator: lead.name, ephemeral: true
      )

      @ui_presenter.display_info("Plan with #{steps.size} tasks:")
      steps.each_with_index do |s, i|
        @ui_presenter.display_info("  #{i + 1}. #{s[:title]} -> #{s[:assignee]}")
      end

      # Step 3: Execute tasks in order
      executor = TaskExecutor.new(task_coordinator: @task_coordinator)
      results  = execute_steps(executor, prompt, plan, steps, robots)

      @tracker.record_turn(
        model: AIA.config.models.first.name,
        input: prompt,
        result: results
      )

      format_results(results)
    end

    private

    def execute_steps(executor, prompt, plan, steps, robots)
      results = []

      plan[:steps].each_with_index do |task, i|
        step_def = steps[i]
        assignee = robots.values.find { |r| r.name == step_def[:assignee] }
        assignee ||= robots.values.first

        @ui_presenter.display_info("  #{assignee.name}: #{step_def[:title]}...")

        content = executor.execute(task, assignee, step_def, prompt, results)

        write_to_memory(i, assignee.name, step_def[:title], content)
        results << { robot: assignee.name, task: step_def[:title], content: content }
      end

      results
    end

    def write_to_memory(index, robot_name, task_title, content)
      return unless @robot.respond_to?(:memory)

      @robot.memory.current_writer = robot_name
      @robot.memory.set(:"delegate_step_#{index}", {
        robot: robot_name, task: task_title, content: content
      })
    end

    def format_results(results)
      lines = []
      results.each_with_index do |r, i|
        lines << "### Step #{i + 1}: #{r[:task]} (#{r[:robot]})"
        lines << r[:content]
        lines << ""
      end
      lines.join("\n")
    end
  end
end
