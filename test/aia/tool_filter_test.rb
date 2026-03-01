# frozen_string_literal: true
# test/aia/tool_filter_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ToolFilterTest < Minitest::Test
  # A concrete subclass for testing the base class behavior.
  class DummyFilter < AIA::ToolFilter
    attr_accessor :prep_called, :dummy_scores

    def initialize(scores: [])
      super(label: "Dummy")
      @prep_called  = false
      @dummy_scores = scores
    end

    protected

    def do_prep
      @prep_called = true
      @tool_count  = @dummy_scores.size
    end

    def do_filter_with_scores(_prompt)
      @dummy_scores
    end
  end

  # =========================================================================
  # Construction
  # =========================================================================

  def test_initialize_sets_label
    f = DummyFilter.new
    assert_equal "Dummy", f.label
  end

  def test_initialize_defaults
    f = DummyFilter.new
    assert_equal 0, f.tool_count
    assert_in_delta 0.0, f.prep_ms
  end

  # =========================================================================
  # prep
  # =========================================================================

  def test_prep_calls_do_prep
    f = DummyFilter.new(scores: [{ name: "t1", score: 0.5 }])
    f.prep
    assert f.prep_called
  end

  def test_prep_captures_timing
    f = DummyFilter.new(scores: [{ name: "t1", score: 0.5 }])
    f.prep
    assert f.prep_ms >= 0.0
  end

  def test_prep_sets_tool_count
    f = DummyFilter.new(scores: [{ name: "t1", score: 0.5 }, { name: "t2", score: 0.3 }])
    f.prep
    assert_equal 2, f.tool_count
  end

  # =========================================================================
  # filter
  # =========================================================================

  def test_filter_returns_names
    f = DummyFilter.new(scores: [{ name: "tool_a", score: 0.5 }, { name: "tool_b", score: 0.3 }])
    result = f.filter("anything")
    assert_equal ["tool_a", "tool_b"], result
  end

  def test_filter_returns_nil_when_empty
    f = DummyFilter.new(scores: [])
    assert_nil f.filter("anything")
  end

  # =========================================================================
  # filter_with_scores
  # =========================================================================

  def test_filter_with_scores_returns_hashes
    scores = [{ name: "t1", score: 0.9 }]
    f = DummyFilter.new(scores: scores)
    assert_equal scores, f.filter_with_scores("anything")
  end

  # =========================================================================
  # available?
  # =========================================================================

  def test_available_false_before_prep
    f = DummyFilter.new(scores: [{ name: "t1", score: 0.5 }])
    refute f.available?
  end

  def test_available_true_after_prep
    f = DummyFilter.new(scores: [{ name: "t1", score: 0.5 }])
    f.prep
    assert f.available?
  end

  def test_available_false_when_no_tools
    f = DummyFilter.new(scores: [])
    f.prep
    refute f.available?
  end

  # =========================================================================
  # persistable?
  # =========================================================================

  def test_persistable_false_by_default
    f = DummyFilter.new
    refute f.persistable?
  end

  # =========================================================================
  # cleanup
  # =========================================================================

  def test_cleanup_is_noop_by_default
    f = DummyFilter.new
    assert_nil f.cleanup
  end

  # =========================================================================
  # NotImplementedError
  # =========================================================================

  def test_bare_base_class_raises_on_prep
    f = AIA::ToolFilter.new(label: "bare")
    assert_raises(NotImplementedError) { f.prep }
  end

  def test_bare_base_class_raises_on_filter_with_scores
    f = AIA::ToolFilter.new(label: "bare")
    assert_raises(NotImplementedError) { f.filter_with_scores("anything") }
  end
end
