# frozen_string_literal: true
# test/aia/session_tracker_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class SessionTrackerTest < Minitest::Test
  def setup
    @tracker = AIA::SessionTracker.new
  end

  def teardown
    super
  end

  # =========================================================================
  # Initialization
  # =========================================================================

  def test_initialization_starts_with_zero_turn_count
    assert_equal 0, @tracker.turn_count
  end

  def test_initialization_starts_with_zero_total_cost
    assert_equal 0.0, @tracker.total_cost
  end

  def test_initialization_starts_with_zero_total_tokens
    assert_equal 0, @tracker.total_tokens
  end

  def test_initialization_starts_with_empty_turns
    assert_empty @tracker.turns
  end

  # =========================================================================
  # record_turn — increments turn_count
  # =========================================================================

  def test_record_turn_increments_turn_count
    result = build_mock_result(input_tokens: 10, output_tokens: 20)

    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)
    assert_equal 1, @tracker.turn_count

    @tracker.record_turn(model: "gpt-4o-mini", input: "world", result: result)
    assert_equal 2, @tracker.turn_count

    @tracker.record_turn(model: "claude-sonnet-4-20250514", input: "test", result: result)
    assert_equal 3, @tracker.turn_count
  end

  # =========================================================================
  # record_turn — accumulates metrics
  # =========================================================================

  def test_record_turn_accumulates_token_counts
    result1 = build_mock_result(input_tokens: 100, output_tokens: 50)
    result2 = build_mock_result(input_tokens: 200, output_tokens: 80)

    @tracker.record_turn(model: "gpt-4o-mini", input: "first", result: result1)
    assert_equal 150, @tracker.total_tokens

    @tracker.record_turn(model: "gpt-4o-mini", input: "second", result: result2)
    assert_equal 430, @tracker.total_tokens
  end

  def test_record_turn_stores_turn_data
    result = build_mock_result(input_tokens: 50, output_tokens: 25)

    @tracker.record_turn(model: "gpt-4o-mini", input: "hello world", result: result)

    assert_equal 1, @tracker.turns.length
    turn = @tracker.turns.first

    assert_equal "gpt-4o-mini", turn[:model]
    assert_equal 11, turn[:input_length]
    assert_equal 75, turn[:tokens]
    assert_instance_of Time, turn[:timestamp]
  end

  def test_record_turn_records_decisions_when_provided
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    mock_decisions = mock('decisions')
    mock_decisions.stubs(:to_h).returns({ classifications: [{ domain: "code" }] })

    @tracker.record_turn(
      model: "gpt-4o-mini",
      input: "test",
      result: result,
      decisions: mock_decisions
    )

    turn = @tracker.turns.first
    assert_equal({ classifications: [{ domain: "code" }] }, turn[:decisions])
  end

  def test_record_turn_records_nil_decisions_when_not_provided
    result = build_mock_result(input_tokens: 10, output_tokens: 5)

    @tracker.record_turn(model: "gpt-4o-mini", input: "test", result: result)

    turn = @tracker.turns.first
    assert_nil turn[:decisions]
  end

  def test_record_turn_handles_result_without_output
    plain_result = Object.new

    @tracker.record_turn(model: "gpt-4o-mini", input: "test", result: plain_result)

    assert_equal 1, @tracker.turn_count
    assert_equal 0, @tracker.total_tokens
    turn = @tracker.turns.first
    assert_equal 0, turn[:tokens]
  end

  def test_record_turn_handles_nil_input
    result = build_mock_result(input_tokens: 10, output_tokens: 5)

    @tracker.record_turn(model: "gpt-4o-mini", input: nil, result: result)

    turn = @tracker.turns.first
    assert_equal 0, turn[:input_length]
  end

  # =========================================================================
  # record_model_switch
  # =========================================================================

  def test_record_model_switch_records_event
    @tracker.record_model_switch(from: "gpt-4o-mini", to: "claude-sonnet-4-20250514")

    assert_equal 1, @tracker.turns.length
    event = @tracker.turns.first

    assert_equal :model_switch, event[:type]
    assert_equal "gpt-4o-mini", event[:from]
    assert_equal "claude-sonnet-4-20250514", event[:to]
    assert_equal "user_request", event[:reason]
    assert_instance_of Time, event[:timestamp]
  end

  def test_record_model_switch_with_custom_reason
    @tracker.record_model_switch(
      from: "gpt-4o-mini",
      to: "gpt-4o",
      reason: "rule_engine"
    )

    event = @tracker.turns.first
    assert_equal "rule_engine", event[:reason]
  end

  def test_record_model_switch_does_not_increment_turn_count
    @tracker.record_model_switch(from: "gpt-4o-mini", to: "gpt-4o")

    assert_equal 0, @tracker.turn_count,
      "Model switch events should not increment turn_count"
  end

  # =========================================================================
  # record_user_feedback
  # =========================================================================

  def test_record_user_feedback_attaches_to_last_turn
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)

    @tracker.record_user_feedback(satisfied: true)

    last_turn = @tracker.turns.last
    assert_equal true, last_turn[:user_satisfied]
  end

  def test_record_user_feedback_negative
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)

    @tracker.record_user_feedback(satisfied: false)

    last_turn = @tracker.turns.last
    assert_equal false, last_turn[:user_satisfied]
  end

  def test_record_user_feedback_does_nothing_when_no_turns
    # Should not raise when turns array is empty
    @tracker.record_user_feedback(satisfied: true)
    assert_empty @tracker.turns
  end

  def test_record_user_feedback_overwrites_previous_feedback
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)

    @tracker.record_user_feedback(satisfied: true)
    assert_equal true, @tracker.turns.last[:user_satisfied]

    @tracker.record_user_feedback(satisfied: false)
    assert_equal false, @tracker.turns.last[:user_satisfied]
  end

  def test_record_user_feedback_attaches_to_model_switch_event_if_last
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)
    @tracker.record_model_switch(from: "gpt-4o-mini", to: "gpt-4o")

    @tracker.record_user_feedback(satisfied: false)

    # Feedback goes to the last entry which is the model switch event
    last_entry = @tracker.turns.last
    assert_equal :model_switch, last_entry[:type]
    assert_equal false, last_entry[:user_satisfied]
  end

  # =========================================================================
  # to_facts
  # =========================================================================

  def test_to_facts_returns_stats_hash
    facts = @tracker.to_facts

    assert_instance_of Hash, facts
    assert_equal 0, facts[:turn_count]
    assert_equal 0.0, facts[:total_cost]
    assert_equal 0, facts[:total_tokens]
  end

  def test_to_facts_reflects_accumulated_state
    result1 = build_mock_result(input_tokens: 100, output_tokens: 50)
    result2 = build_mock_result(input_tokens: 200, output_tokens: 100)

    @tracker.record_turn(model: "gpt-4o-mini", input: "first", result: result1)
    @tracker.record_turn(model: "gpt-4o-mini", input: "second", result: result2)

    facts = @tracker.to_facts

    assert_equal 2, facts[:turn_count]
    assert_equal 450, facts[:total_tokens]
    assert_kind_of Numeric, facts[:total_cost]
  end

  def test_to_facts_contains_required_keys
    facts = @tracker.to_facts

    assert facts.key?(:turn_count), "Expected :turn_count key"
    assert facts.key?(:total_cost), "Expected :total_cost key"
    assert facts.key?(:total_tokens), "Expected :total_tokens key"
  end

  # =========================================================================
  # reset!
  # =========================================================================

  def test_reset_clears_turn_count
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)
    assert_equal 1, @tracker.turn_count

    @tracker.reset!

    assert_equal 0, @tracker.turn_count
  end

  def test_reset_clears_total_cost
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)

    @tracker.reset!

    assert_equal 0.0, @tracker.total_cost
  end

  def test_reset_clears_total_tokens
    result = build_mock_result(input_tokens: 100, output_tokens: 50)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)
    assert_equal 150, @tracker.total_tokens

    @tracker.reset!

    assert_equal 0, @tracker.total_tokens
  end

  def test_reset_clears_turns
    result = build_mock_result(input_tokens: 10, output_tokens: 5)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)
    @tracker.record_model_switch(from: "gpt-4o-mini", to: "gpt-4o")
    refute_empty @tracker.turns

    @tracker.reset!

    assert_empty @tracker.turns
  end

  def test_reset_clears_everything
    result = build_mock_result(input_tokens: 100, output_tokens: 50)
    @tracker.record_turn(model: "gpt-4o-mini", input: "hello", result: result)
    @tracker.record_turn(model: "gpt-4o", input: "world", result: result)
    @tracker.record_model_switch(from: "gpt-4o-mini", to: "gpt-4o")
    @tracker.record_user_feedback(satisfied: true)

    @tracker.reset!

    assert_equal 0, @tracker.turn_count
    assert_equal 0.0, @tracker.total_cost
    assert_equal 0, @tracker.total_tokens
    assert_empty @tracker.turns

    # to_facts should also reflect the reset
    facts = @tracker.to_facts
    assert_equal 0, facts[:turn_count]
    assert_equal 0.0, facts[:total_cost]
    assert_equal 0, facts[:total_tokens]
  end

  def test_reset_allows_fresh_recording
    result = build_mock_result(input_tokens: 100, output_tokens: 50)
    @tracker.record_turn(model: "gpt-4o-mini", input: "before reset", result: result)

    @tracker.reset!

    @tracker.record_turn(model: "gpt-4o", input: "after reset", result: result)

    assert_equal 1, @tracker.turn_count
    assert_equal 150, @tracker.total_tokens
    assert_equal 1, @tracker.turns.length
    assert_equal "gpt-4o", @tracker.turns.first[:model]
  end

  private

  # Build a mock LLM result with token counts that SessionTracker can extract.
  # Mirrors the structure expected by SessionTracker#extract_metrics.
  def build_mock_result(input_tokens: 0, output_tokens: 0)
    last_msg = mock('last_message')
    last_msg.stubs(:input_tokens).returns(input_tokens)
    last_msg.stubs(:output_tokens).returns(output_tokens)

    output = [last_msg]

    result = mock('result')
    result.stubs(:output).returns(output)
    result
  end
end
