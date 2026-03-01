# frozen_string_literal: true
# test/aia/tool_filter/kbs_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'
require 'ostruct'

class ToolFilterKBSTest < Minitest::Test
  # =========================================================================
  # Test helpers
  # =========================================================================

  def make_turn_state(active_tools: nil)
    ts = AIA::TurnState.new
    ts.active_tools = active_tools
    ts
  end

  def make_rule_router(tools_count: 5)
    router = Object.new
    router.define_singleton_method(:register_tools) { |tools| }
    router
  end

  def make_tools(count = 5)
    count.times.map do |i|
      t = Object.new
      t.define_singleton_method(:name) { "tool_#{i}" }
      t.define_singleton_method(:description) { "Description for tool #{i}" }
      t
    end
  end

  def build_filter(tools: nil, rule_router: nil)
    tools ||= make_tools
    rule_router ||= make_rule_router
    AIA::ToolFilter::KBS.new(rule_router: rule_router, tools: tools)
  end

  # =========================================================================
  # Construction
  # =========================================================================

  def test_initialize_sets_label
    filter = build_filter
    assert_equal "KBS", filter.label
  end

  def test_initialize_defaults
    filter = build_filter
    assert_equal 0, filter.tool_count
    assert_in_delta 0.0, filter.last_turn_ms
  end

  # =========================================================================
  # prep
  # =========================================================================

  def test_prep_registers_tools
    router = mock('rule_router')
    tools = make_tools(3)
    router.expects(:register_tools).with(tools).once

    filter = AIA::ToolFilter::KBS.new(rule_router: router, tools: tools)
    filter.prep
  end

  def test_prep_sets_tool_count
    filter = build_filter(tools: make_tools(7))
    filter.prep
    assert_equal 7, filter.tool_count
  end

  def test_prep_captures_timing
    filter = build_filter
    filter.prep
    assert filter.prep_ms >= 0.0
  end

  def test_available_after_prep
    filter = build_filter
    filter.prep
    assert filter.available?
  end

  # =========================================================================
  # filter_with_scores
  # =========================================================================

  def test_filter_reads_turn_state_active_tools
    filter = build_filter
    filter.prep

    ts = make_turn_state(active_tools: ["tool_x", "tool_y"])
    AIA.stubs(:turn_state).returns(ts)

    result = filter.filter_with_scores("some prompt")
    assert_equal 2, result.size
    assert_equal "tool_x", result[0][:name]
    assert_equal 1.0, result[0][:score]
  end

  def test_filter_returns_empty_when_no_active_tools
    filter = build_filter
    filter.prep

    ts = make_turn_state(active_tools: nil)
    AIA.stubs(:turn_state).returns(ts)

    result = filter.filter_with_scores("some prompt")
    assert_equal [], result
  end

  def test_filter_returns_nil_via_base_filter_when_empty
    filter = build_filter
    filter.prep

    ts = make_turn_state(active_tools: nil)
    AIA.stubs(:turn_state).returns(ts)

    assert_nil filter.filter("some prompt")
  end

  def test_filter_returns_names_via_base_filter
    filter = build_filter
    filter.prep

    ts = make_turn_state(active_tools: ["tool_a", "tool_b"])
    AIA.stubs(:turn_state).returns(ts)

    assert_equal ["tool_a", "tool_b"], filter.filter("some prompt")
  end

  # =========================================================================
  # record_turn_ms
  # =========================================================================

  def test_record_turn_ms
    filter = build_filter
    assert_in_delta 0.0, filter.last_turn_ms

    filter.record_turn_ms(42.5)
    assert_in_delta 42.5, filter.last_turn_ms
  end
end
