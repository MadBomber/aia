# frozen_string_literal: true

# lib/aia/directives/trakflow_directives.rb
#
# Chat directives for interacting with TrakFlow task tracking.

module AIA
  class TrakFlowDirectives < Directive
    desc "Show TrakFlow ready tasks and project summary"
    def tasks(args, context_manager = nil)
      bridge = TrakFlowBridge.new
      return "TrakFlow not available. Run 'tf init' to initialize a project." unless bridge.available?

      if args.first == "summary"
        bridge.project_summary || "No summary available."
      else
        bridge.check_ready_tasks || "No ready tasks found."
      end
    end
    alias_method :tf, :tasks

    desc "Create a TrakFlow plan from a description"
    def plan(args, context_manager = nil)
      bridge = TrakFlowBridge.new
      return "TrakFlow not available. Run 'tf init' to initialize a project." unless bridge.available?

      description = args.join(' ')
      return "Usage: /plan <description>" if description.empty?

      bridge.create_task(description) || "Failed to create plan."
    end

    desc "Create a TrakFlow task"
    def task(args, context_manager = nil)
      bridge = TrakFlowBridge.new
      return "TrakFlow not available. Run 'tf init' to initialize a project." unless bridge.available?

      title = args.join(' ')
      return "Usage: /task <title>" if title.empty?

      bridge.create_task(title) || "Failed to create task."
    end
  end
end
