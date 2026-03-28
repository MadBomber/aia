# frozen_string_literal: true

# lib/aia/task_executor.rb
#
# Extracts step execution logic from DelegateHandler.
# Runs a single subtask against the assigned robot and records
# the result in the task coordinator.

module AIA
  class TaskExecutor
    include ContentExtractor

    def initialize(task_coordinator:)
      @coordinator = task_coordinator
    end

    # Execute a single task step against the assigned robot.
    #
    # @param task [Object] TrakFlow task object (responds to #id)
    # @param robot [RobotLab::Robot] the assigned robot
    # @param step_def [Hash] step definition with :title
    # @param prompt [String] the original user prompt
    # @param prior_results [Array<Hash>] results from previous steps
    # @return [String] the robot's response content
    def execute(task, robot, step_def, prompt, prior_results)
      @coordinator.claim_task(task.id, robot.name)

      context = build_step_context(prompt, step_def[:title], prior_results)
      result  = robot.run(context, mcp: :inherit, tools: :inherit)
      content = extract_content(result)

      @coordinator.complete_task(task.id, result: content[0, 200], robot_name: robot.name)
      content
    end

    private

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
  end
end
