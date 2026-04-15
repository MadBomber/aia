# frozen_string_literal: true
# test/aia/tool_filter_strategy_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require 'ostruct'

class ToolFilterStrategyTest < Minitest::Test
  # =========================================================================
  # Test helpers
  # =========================================================================

  def make_turn_state(active_tools: nil)
    ts = AIA::TurnState.new
    ts.active_tools = active_tools
    ts
  end

  # Build a mock ToolFilter with given scored results
  def make_mock_filter(label:, scored: [], prep_ms: 1.0, tool_count: nil)
    tool_count ||= scored.size
    filter = Object.new
    filter.define_singleton_method(:label) { label }
    filter.define_singleton_method(:prep_ms) { prep_ms }
    filter.define_singleton_method(:tool_count) { tool_count }
    filter.define_singleton_method(:available?) { tool_count > 0 }
    filter.define_singleton_method(:filter_with_scores) { |_prompt| scored }
    filter.define_singleton_method(:filter) { |_prompt|
      names = scored.map { |e| e[:name] }
      names.empty? ? nil : names
    }
    filter
  end

  def build_strategy(filters: {})
    ui = OpenStruct.new
    AIA::ToolFilterStrategy.new(filters: filters, ui_presenter: ui)
  end

  def with_aia_state(turn_state: nil)
    turn_state ||= make_turn_state
    AIA.stubs(:turn_state).returns(turn_state)
    turn_state
  end

  # =========================================================================
  # Strategy selection (active_strategy_label)
  # =========================================================================

  def test_tfidf_only_label
    tfidf = make_mock_filter(label: "TF-IDF", scored: [{ name: "t", score: 0.5 }])
    strategy = build_strategy(filters: { tfidf: tfidf })
    assert_equal "TF-IDF", strategy.active_strategy_label
  end

  def test_empty_filters_fallback_label
    strategy = build_strategy(filters: {})
    assert_equal "none", strategy.active_strategy_label
  end

  def test_unavailable_filter_excluded_from_label
    tfidf = make_mock_filter(label: "TF-IDF", scored: [{ name: "t", score: 0.5 }])
    empty_filter = make_mock_filter(label: "TF-IDF", scored: [], tool_count: 0)
    strategy = build_strategy(filters: { tfidf: tfidf, extra: empty_filter })
    assert_equal "TF-IDF", strategy.active_strategy_label
  end

  # =========================================================================
  # TF-IDF resolution (single filter)
  # =========================================================================

  def test_tfidf_returns_filtered_tools
    tfidf = make_mock_filter(
      label: "TF-IDF",
      scored: [{ name: "search_tool", score: 0.5 }, { name: "code_tool", score: 0.3 }]
    )
    strategy = build_strategy(filters: { tfidf: tfidf })

    result = strategy.resolve("find files")
    assert_equal ["search_tool", "code_tool"], result
  end

  def test_tfidf_returns_nil_when_no_matches
    tfidf = make_mock_filter(label: "TF-IDF", scored: [])
    strategy = build_strategy(filters: { tfidf: tfidf })

    assert_nil strategy.resolve("something obscure")
  end

  # =========================================================================
  # No filters
  # =========================================================================

  def test_no_filters_returns_nil
    strategy = build_strategy(filters: {})
    assert_nil strategy.resolve("some prompt")
  end

  # =========================================================================
  # Error handling — single filter failure
  # =========================================================================

  def test_single_filter_raises_returns_nil
    failing_filter = make_mock_filter(label: "TF-IDF", scored: [], tool_count: 1)
    failing_filter.define_singleton_method(:filter_with_scores) do |_prompt|
      raise RuntimeError, "embedding model failed to load"
    end

    strategy = build_strategy(filters: { tfidf: failing_filter })
    assert_nil strategy.resolve("some prompt")
  end
end
