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
      # @param db_dir [String, nil] directory for keyword rules persist file
      # @param load_db [Boolean] load persisted keyword data if available
      # @param save_db [Boolean] persist keyword data to disk after computing
      def initialize(rule_router:, tools:, db_dir: nil, load_db: false, save_db: false)
        super(label: "KBS")
        @rule_router  = rule_router
        @tools        = tools
        @db_dir       = db_dir
        @load_db      = load_db
        @save_db      = save_db
        @last_turn_ms = 0.0
      end

      # Record the KBS evaluate_turn+apply time for this turn.
      # Called by ChatLoop after the KBS evaluate/apply cycle.
      def record_turn_ms(ms)
        @last_turn_ms = ms
      end

      protected

      def do_prep
        @rule_router.register_tools(@tools, db_dir: @db_dir, load_db: @load_db, save_db: @save_db)
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
