# frozen_string_literal: true

# lib/aia/tool_filter/kbs.rb
#
# KBS rule-based tool filter (Option A).
# Wraps RuleRouter#register_tools for prep and reads
# AIA.turn_state.active_tools for per-turn filtering.

module AIA
  class ToolFilter
    class KBS < ToolFilter
      attr_reader :last_turn_ms

      # @param rule_router [RuleRouter] the KBS rule router instance
      # @param tools [Array] tool classes/objects with .name and .description
      def initialize(rule_router:, tools:)
        super(label: "KBS")
        @rule_router  = rule_router
        @tools        = tools
        @last_turn_ms = 0.0
      end

      # Record the KBS evaluate_turn+apply time for this turn.
      # Called by ChatLoop after the KBS evaluate/apply cycle.
      def record_turn_ms(ms)
        @last_turn_ms = ms
      end

      protected

      def do_prep
        @rule_router.register_tools(@tools)
        @tool_count = @tools.size
      end

      def do_filter_with_scores(_prompt)
        tools = AIA.turn_state&.active_tools
        return [] if tools.nil? || tools.empty?

        tools.map { |name| { name: name, score: 1.0 } }
      end
    end
  end
end
