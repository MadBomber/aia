# frozen_string_literal: true

# lib/aia/tool_utility.rb
#
# Pure tool state-query methods mixed into AIA::Utility via `class << self include`.
# No display or formatting concerns — those live in Utility directly.

module AIA
  module ToolUtility
    def tools?
      names = AIA.config&.tool_names
      return true if names && !names.empty?
      total_tool_count.positive?
    end

    def total_tool_count
      config = AIA.config
      local  = Array(config&.loaded_tools).size
      return local if config&.flags&.no_mcp
      local + (config&.mcp_server_tool_counts || {}).values.sum
    end

    def user_tools?
      AIA.config&.tools&.paths&.any?
    end

    def supports_tools?
      AIA.client&.model&.supports_functions? || false
    end
  end
end
