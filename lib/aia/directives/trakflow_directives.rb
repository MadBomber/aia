# frozen_string_literal: true

# lib/aia/directives/trakflow_directives.rb
#
# Chat directives for interacting with TrakFlow task tracking.

module AIA
  class TrakFlowDirectives < Directive
    desc "Show TrakFlow ready tasks and project summary"
    def tasks(args, context_manager = nil)
      bridge = build_bridge
      return "TrakFlow not available. Connect the trak_flow MCP server." unless bridge&.available?

      if args.first == "summary"
        bridge.project_summary || "No summary available."
      else
        bridge.check_ready_tasks || "No ready tasks found."
      end
    end
    alias_method :tf, :tasks

    desc "Create a TrakFlow plan from a description"
    def plan(args, context_manager = nil)
      bridge = build_bridge
      return "TrakFlow not available. Connect the trak_flow MCP server." unless bridge&.available?

      description = args.join(' ')
      return "Usage: /plan <description>" if description.empty?

      AIA.client.run(
        "Create a TrakFlow plan: #{description}",
        mcp: :inherit, tools: :none
      ).to_s
    end

    desc "Create a TrakFlow task"
    def task(args, context_manager = nil)
      bridge = build_bridge
      return "TrakFlow not available. Connect the trak_flow MCP server." unless bridge&.available?

      title = args.join(' ')
      return "Usage: /task <title>" if title.empty?

      bridge.create_task(title) || "Failed to create task."
    end

    private

    def build_bridge
      return nil unless AIA.client
      TrakFlowBridge.new(AIA.client)
    end
  end
end
