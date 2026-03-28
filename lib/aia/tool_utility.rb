# frozen_string_literal: true

# lib/aia/tool_utility.rb
#
# Pure tool state-query methods mixed into AIA::Utility via `class << self include`.
# No display or formatting concerns — those live in Utility directly.

module AIA
  module ToolUtility
    def tools?
      return true if AIA.config&.tool_names && !AIA.config.tool_names.empty?
      total_tool_count > 0
    end

    def total_tool_count
      local = Array(AIA.config&.loaded_tools).size
      return local if AIA.config&.flags&.no_mcp
      mcp = defined?(RubyLLM::MCP) ? RubyLLM::MCP.clients.sum { |_, c| c.tools.count } : 0
      local + mcp
    end

    def user_tools?
      AIA.config&.tools&.paths&.any?
    end

    def supports_tools?
      AIA.client&.model&.supports_functions? || false
    end
  end
end
