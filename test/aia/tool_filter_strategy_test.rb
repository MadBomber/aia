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

  def test_zvec_only_label
    zvec = make_mock_filter(label: "Zvec", scored: [{ name: "t", score: 0.8 }])
    strategy = build_strategy(filters: { zvec: zvec })
    assert_equal "Zvec", strategy.active_strategy_label
  end

  def test_tfidf_zvec_comparison_label
    tfidf = make_mock_filter(label: "TF-IDF", scored: [{ name: "t", score: 0.5 }])
    zvec = make_mock_filter(label: "Zvec", scored: [{ name: "t", score: 0.8 }])
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: zvec })
    assert_equal "TF-IDF+Zvec comparison", strategy.active_strategy_label
  end

  def test_all_three_comparison_label
    tfidf = make_mock_filter(label: "TF-IDF", scored: [{ name: "t", score: 0.5 }])
    zvec = make_mock_filter(label: "Zvec", scored: [{ name: "t", score: 0.8 }])
    sqlite_vec = make_mock_filter(label: "SqVec", scored: [{ name: "t", score: 0.7 }])
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: zvec, sqlite_vec: sqlite_vec })
    assert_equal "TF-IDF+Zvec+SqVec comparison", strategy.active_strategy_label
  end

  def test_empty_filters_fallback_label
    strategy = build_strategy(filters: {})
    assert_equal "none", strategy.active_strategy_label
  end

  def test_unavailable_filter_excluded_from_label
    tfidf = make_mock_filter(label: "TF-IDF", scored: [{ name: "t", score: 0.5 }])
    empty_zvec = make_mock_filter(label: "Zvec", scored: [], tool_count: 0)
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: empty_zvec })
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
  # Zvec resolution (single filter)
  # =========================================================================

  def test_zvec_returns_filtered_tools
    zvec = make_mock_filter(
      label: "Zvec",
      scored: [{ name: "search_tool", score: 0.8 }, { name: "code_tool", score: 0.6 }]
    )
    strategy = build_strategy(filters: { zvec: zvec })

    result = strategy.resolve("find files")
    assert_equal ["search_tool", "code_tool"], result
  end

  def test_zvec_returns_nil_when_no_matches
    zvec = make_mock_filter(label: "Zvec", scored: [])
    strategy = build_strategy(filters: { zvec: zvec })

    assert_nil strategy.resolve("something obscure")
  end

  # =========================================================================
  # Comparison mode (A+B = TF-IDF+Zvec)
  # =========================================================================

  def test_comparison_mode_defaults_to_tfidf_on_a_input
    tfidf = make_mock_filter(
      label: "TF-IDF",
      scored: [{ name: "tfidf_tool", score: 0.5 }]
    )
    zvec = make_mock_filter(
      label: "Zvec",
      scored: [{ name: "zvec_tool", score: 0.8 }]
    )
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: zvec })

    $stdin.stubs(:gets).returns("a\n")
    result = strategy.resolve("test prompt")
    assert_equal ["tfidf_tool"], result
  end

  def test_comparison_mode_picks_zvec_on_b_choice
    tfidf = make_mock_filter(
      label: "TF-IDF",
      scored: [{ name: "tfidf_tool", score: 0.5 }]
    )
    zvec = make_mock_filter(
      label: "Zvec",
      scored: [{ name: "zvec_tool", score: 0.8 }]
    )
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: zvec })

    $stdin.stubs(:gets).returns("b\n")
    result = strategy.resolve("test prompt")
    assert_equal ["zvec_tool"], result
  end

  def test_comparison_mode_merges_on_m_choice
    tfidf = make_mock_filter(
      label: "TF-IDF",
      scored: [{ name: "shared_tool", score: 0.5 }, { name: "tfidf_only", score: 0.3 }]
    )
    zvec = make_mock_filter(
      label: "Zvec",
      scored: [{ name: "shared_tool", score: 0.8 }, { name: "zvec_only", score: 0.6 }]
    )
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: zvec })

    $stdin.stubs(:gets).returns("m\n")
    result = strategy.resolve("test prompt")
    assert_includes result, "shared_tool"
    assert_includes result, "tfidf_only"
    assert_includes result, "zvec_only"
    assert_equal 3, result.size, "Merged should deduplicate"
  end

  # =========================================================================
  # Comparison mode with three filters (A+B+C)
  # =========================================================================

  def test_comparison_mode_picks_sqlite_vec_on_c_choice
    tfidf = make_mock_filter(
      label: "TF-IDF",
      scored: [{ name: "tfidf_tool", score: 0.5 }]
    )
    zvec = make_mock_filter(
      label: "Zvec",
      scored: [{ name: "zvec_tool", score: 0.8 }]
    )
    sqlite_vec = make_mock_filter(
      label: "SqVec",
      scored: [{ name: "sqvec_tool", score: 0.7 }]
    )
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: zvec, sqlite_vec: sqlite_vec })

    $stdin.stubs(:gets).returns("c\n")
    result = strategy.resolve("test prompt")
    assert_equal ["sqvec_tool"], result
  end

  def test_comparison_mode_merges_all_three
    tfidf = make_mock_filter(
      label: "TF-IDF",
      scored: [{ name: "tfidf_tool", score: 0.5 }]
    )
    zvec = make_mock_filter(
      label: "Zvec",
      scored: [{ name: "zvec_tool", score: 0.8 }]
    )
    sqlite_vec = make_mock_filter(
      label: "SqVec",
      scored: [{ name: "sqvec_tool", score: 0.7 }]
    )
    strategy = build_strategy(filters: { tfidf: tfidf, zvec: zvec, sqlite_vec: sqlite_vec })

    $stdin.stubs(:gets).returns("m\n")
    result = strategy.resolve("test prompt")
    assert_includes result, "tfidf_tool"
    assert_includes result, "zvec_tool"
    assert_includes result, "sqvec_tool"
    assert_equal 3, result.size, "Merged should include all unique tools"
  end

  # =========================================================================
  # No filters
  # =========================================================================

  def test_no_filters_returns_nil
    strategy = build_strategy(filters: {})
    assert_nil strategy.resolve("some prompt")
  end
end
