# frozen_string_literal: true

# lib/aia/delegate_handler.rb
#
# Lead robot analyzes a prompt, creates a TrakFlow plan with steps
# assigned to specific robots, then each robot executes its tasks
# in dependency order. Combines TypedBus, SharedMemory, and TrakFlow.

require "json"

module AIA
  class DelegateHandler
    include ContentExtractor

    def initialize(robot:, ui_presenter:, tracker:, task_coordinator:)
      @robot            = robot
      @ui_presenter     = ui_presenter
      @tracker          = tracker
      @task_coordinator = task_coordinator
    end

    attr_writer :robot

    # Decompose a prompt into subtasks, assign to robots, and execute.
    #
    # @param prompt [String]
    # @return [String, nil] combined results, or nil if not applicable
    def handle(prompt)
      return nil unless @robot.is_a?(RobotLab::Network)
      return nil unless @task_coordinator&.available?

      robots      = @robot.robots
      robot_names = robots.values.map(&:name)
      lead        = robots.values.first

      # Step 1: Lead robot decomposes the work
      @ui_presenter.display_info("#{lead.name} analyzing and delegating...")

      plan_result = lead.run(<<~PROMPT, mcp: :none, tools: :none)
        Break this request into subtasks. Assign each to the most
        appropriate team member based on their model capabilities.

        Team: #{robot_names.join(', ')}
        Request: #{prompt}

        Respond with ONLY a JSON array:
        [{"title": "subtask description", "assignee": "robot_name"}]
      PROMPT

      reply = extract_reply(plan_result)
      steps = parse_plan(reply, robot_names)

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
      results = execute_steps(prompt, plan, steps, robots)

      @tracker.record_turn(
        model: AIA.config.models.first.name,
        input: prompt,
        result: results
      )

      format_results(results)
    end

    private

    def execute_steps(prompt, plan, steps, robots)
      results = []

      plan[:steps].each_with_index do |task, i|
        step_def = steps[i]
        assignee = robots.values.find { |r| r.name == step_def[:assignee] }
        assignee ||= robots.values.first

        @task_coordinator.claim_task(task.id, assignee.name)
        @ui_presenter.display_info("  #{assignee.name}: #{step_def[:title]}...")

        context = build_step_context(prompt, step_def[:title], results)
        step_result = assignee.run(context, mcp: :inherit, tools: :inherit)
        content = extract_reply(step_result)

        @task_coordinator.complete_task(
          task.id, result: content[0, 200], robot_name: assignee.name
        )

        # Store in shared memory
        write_to_memory(i, assignee.name, step_def[:title], content)

        results << { robot: assignee.name, task: step_def[:title], content: content }
      end

      results
    end

    def build_step_context(prompt, task_title, prior_results)
      context = "Original request: #{prompt}\n\n"

      unless prior_results.empty?
        prior = prior_results.map { |r|
          "#{r[:robot]} completed '#{r[:task]}':\n#{r[:content]}"
        }.join("\n\n")
        context += "Prior work:\n#{prior}\n\n"
      end

      context + "Your task: #{task_title}"
    end

    def write_to_memory(index, robot_name, task_title, content)
      return unless @robot.respond_to?(:memory)

      @robot.memory.current_writer = robot_name
      @robot.memory.set(:"delegate_step_#{index}", {
        robot: robot_name, task: task_title, content: content
      })
    end

    def parse_plan(json_text, valid_names)
      match = json_text.to_s.match(/\[.*\]/m)
      return [] unless match

      JSON.parse(match[0], symbolize_names: true).map do |step|
        assignee = valid_names.include?(step[:assignee]) ? step[:assignee] : valid_names.first
        { title: step[:title].to_s, assignee: assignee }
      end
    rescue JSON::ParserError
      []
    end

    def extract_reply(result)
      result.respond_to?(:reply) ? result.reply : result.to_s
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
