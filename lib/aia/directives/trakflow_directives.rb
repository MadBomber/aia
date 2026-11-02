# frozen_string_literal: true

# lib/aia/directives/trakflow_directives.rb
#
# Chat directives for interacting with TrakFlow task tracking.

module AIA
  class TrakFlowDirectives < Directive
    desc "Show TrakFlow ready tasks and project summary"
    def tasks(args, context_manager = nil)
      bridge = TrakFlowBridge.new
      return report_error("TrakFlow not available. Run 'tf init' to initialize a project.") unless bridge.available?

      if args.first == "summary"
        bridge.project_summary || report_status("No summary available.")
      else
        bridge.check_ready_tasks || report_status("No ready tasks found.")
      end
    end
    alias tf tasks

    desc "Create a TrakFlow plan from a description"
    def plan(args, context_manager = nil)
      bridge = TrakFlowBridge.new
      return report_error("TrakFlow not available. Run 'tf init' to initialize a project.") unless bridge.available?

      description = args.join(' ')
      return report_error("Usage: /plan <description>") if description.empty?

      bridge.create_task(description) || report_error("Failed to create plan.")
    end

    desc "Create a TrakFlow task"
    def task(args, context_manager = nil)
      bridge = TrakFlowBridge.new
      return report_error("TrakFlow not available. Run 'tf init' to initialize a project.") unless bridge.available?

      title = args.join(' ')
      return report_error("Usage: /task <title>") if title.empty?

      bridge.create_task(title) || report_error("Failed to create task.")
    end

    private

    # Log and print a directive error, then return nil so the chat loop
    # skips forwarding it to the robot (an error is not conversational output).
    def report_error(msg)
      AIA::LoggerManager.aia_logger.error(msg)
      puts msg
      nil
    end

    # Same as report_error, but for a non-error empty-result status
    # (e.g. "no ready tasks found") rather than a failure.
    def report_status(msg)
      AIA::LoggerManager.aia_logger.info(msg)
      puts msg
      nil
    end
  end
end
