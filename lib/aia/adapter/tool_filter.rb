# lib/aia/adapter/tool_filter.rb
# frozen_string_literal: true

require 'set'

module AIA
  module Adapter
    class ToolFilter
      def self.filter_allowed(tools)
        allowed = AIA.config.tools.allowed
        return tools if allowed.nil? || allowed.empty?

        allowed_list = Array(allowed).map(&:strip)

        tools.select do |tool|
          tool_name = tool.respond_to?(:name) ? tool.name : tool.class.name
          allowed_list.any? { |allowed_pattern| tool_name.include?(allowed_pattern) }
        end
      end

      def self.filter_rejected(tools)
        rejected = AIA.config.tools.rejected
        return tools if rejected.nil? || rejected.empty?

        rejected_list = Array(rejected).map(&:strip)

        tools.reject do |tool|
          tool_name = tool.respond_to?(:name) ? tool.name : tool.class.name
          rejected_list.any? { |rejected_pattern| tool_name.include?(rejected_pattern) }
        end
      end

      def self.drop_duplicates(tools)
        seen_names = Set.new
        original_size = tools.size

        logger = LoggerManager.aia_logger
        logger.debug("Checking tools for duplicates", tool_count: original_size)

        result = tools.select do |tool|
          tool_name = tool.name
          if seen_names.include?(tool_name)
            logger.warn("Duplicate tool detected - keeping first occurrence only", tool: tool_name)
            warn "WARNING: Duplicate tool name detected: '#{tool_name}'. Only the first occurrence will be used."
            false
          else
            seen_names.add(tool_name)
            true
          end
        end

        removed_count = original_size - result.size
        if removed_count > 0
          logger.info("Removed duplicate tools", removed_count: removed_count, remaining_count: result.size)
          warn "Removed #{removed_count} duplicate tools"
        else
          logger.debug("No duplicate tools found")
        end

        result
      end
    end
  end
end
