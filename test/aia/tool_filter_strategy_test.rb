# frozen_string_literal: true
# test/aia/tool_filter_strategy_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require 'ostruct'

class ToolFilterStrategyTest < Minitest::Test
  # =========================================================================
  # Test helpers
  # =========================================================================

  def make_flags(tool_filter_a: true, tool_filter_b: false)
    OpenStruct.new(
      tool_filter_a: tool_filter_a,
      tool_filter_b: tool_filter_b,
      debug: false,
      verbose: false,
      chat: false
    )
  end

  def make_config(tool_filter_a: true, tool_filter_b: false)
    OpenStruct.new(flags: make_flags(tool_filter_a: tool_filter_a, tool_filter_b: tool_filter_b))
  end

  def make_turn_state(active_tools: nil)
    ts = AIA::TurnState.new
    ts.active_tools = active_tools
    ts
  end

  def make_tfidf_filter(result: ["tool_a", "tool_b"])
    filter = Object.new
    scored = result.map { |name| { name: name, score: 0.5 } }
    filter.define_singleton_method(:filter) { |_prompt| result }
    filter.define_singleton_method(:filter_with_scores) { |_prompt| scored }
    filter
  end

  def build_strategy(tfidf_filter: nil)
    ui = OpenStruct.new
    AIA::ToolFilterStrategy.new(tfidf_filter: tfidf_filter, ui_presenter: ui)
  end

  def with_aia_state(config:, turn_state: nil)
    turn_state ||= make_turn_state
    AIA.stubs(:config).returns(config)
    AIA.stubs(:turn_state).returns(turn_state)
    turn_state
  end

  # =========================================================================
  # Strategy selection
  # =========================================================================

  def test_default_uses_kbs_strategy
    with_aia_state(config: make_config)
    strategy = build_strategy
    assert_equal "A (KBS)", strategy.active_strategy_label
  end

  def test_b_flag_uses_tfidf_strategy
    with_aia_state(config: make_config(tool_filter_a: false, tool_filter_b: true))
    strategy = build_strategy(tfidf_filter: make_tfidf_filter)
    assert_equal "B (TF-IDF)", strategy.active_strategy_label
  end

  def test_both_flags_uses_comparison
    with_aia_state(config: make_config(tool_filter_a: true, tool_filter_b: true))
    strategy = build_strategy(tfidf_filter: make_tfidf_filter)
    assert_equal "A+B comparison", strategy.active_strategy_label
  end

  # =========================================================================
  # KBS resolution (Option A)
  # =========================================================================

  def test_kbs_returns_turn_state_active_tools
    ts = with_aia_state(
      config: make_config,
      turn_state: make_turn_state(active_tools: ["tool_x", "tool_y"])
    )
    strategy = build_strategy
    result = strategy.resolve("some prompt")
    assert_equal ["tool_x", "tool_y"], result
  end

  def test_kbs_returns_nil_when_no_active_tools
    with_aia_state(config: make_config, turn_state: make_turn_state(active_tools: nil))
    strategy = build_strategy
    assert_nil strategy.resolve("some prompt")
  end

  # =========================================================================
  # TF-IDF resolution (Option B)
  # =========================================================================

  def test_tfidf_returns_filtered_tools
    with_aia_state(config: make_config(tool_filter_a: false, tool_filter_b: true))
    tfidf = make_tfidf_filter(result: ["search_tool", "code_tool"])
    strategy = build_strategy(tfidf_filter: tfidf)

    result = strategy.resolve("find files")
    assert_equal ["search_tool", "code_tool"], result
  end

  def test_tfidf_returns_nil_when_no_matches
    with_aia_state(config: make_config(tool_filter_a: false, tool_filter_b: true))
    tfidf = make_tfidf_filter(result: [])
    strategy = build_strategy(tfidf_filter: tfidf)

    assert_nil strategy.resolve("something obscure")
  end

  def test_tfidf_falls_back_to_kbs_when_filter_nil
    with_aia_state(
      config: make_config(tool_filter_a: false, tool_filter_b: true),
      turn_state: make_turn_state(active_tools: ["fallback_tool"])
    )
    strategy = build_strategy(tfidf_filter: nil)

    # Without a tfidf_filter, falls through to KBS path
    result = strategy.resolve("some prompt")
    assert_equal ["fallback_tool"], result
  end

  # =========================================================================
  # Comparison mode (A+B)
  # =========================================================================

  def test_comparison_mode_defaults_to_kbs_on_no_input
    with_aia_state(
      config: make_config(tool_filter_a: true, tool_filter_b: true),
      turn_state: make_turn_state(active_tools: ["kbs_tool"])
    )
    tfidf = make_tfidf_filter(result: ["tfidf_tool"])
    strategy = build_strategy(tfidf_filter: tfidf)

    $stdin.stubs(:gets).returns("a\n")
    result = strategy.resolve("test prompt")
    assert_equal ["kbs_tool"], result
  end

  def test_comparison_mode_picks_tfidf_on_b_choice
    with_aia_state(
      config: make_config(tool_filter_a: true, tool_filter_b: true),
      turn_state: make_turn_state(active_tools: ["kbs_tool"])
    )
    tfidf = make_tfidf_filter(result: ["tfidf_tool"])
    strategy = build_strategy(tfidf_filter: tfidf)

    $stdin.stubs(:gets).returns("b\n")
    result = strategy.resolve("test prompt")
    assert_equal ["tfidf_tool"], result
  end

  def test_comparison_mode_merges_on_m_choice
    with_aia_state(
      config: make_config(tool_filter_a: true, tool_filter_b: true),
      turn_state: make_turn_state(active_tools: ["shared_tool", "kbs_only"])
    )
    tfidf = make_tfidf_filter(result: ["shared_tool", "tfidf_only"])
    strategy = build_strategy(tfidf_filter: tfidf)

    $stdin.stubs(:gets).returns("m\n")
    result = strategy.resolve("test prompt")
    assert_includes result, "shared_tool"
    assert_includes result, "kbs_only"
    assert_includes result, "tfidf_only"
    assert_equal 3, result.size, "Merged should deduplicate"
  end
end
