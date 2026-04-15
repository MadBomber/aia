# frozen_string_literal: true

# test/aia/directives/execution_directives_test.rb

require_relative '../../test_helper'
require 'ostruct'

class ExecutionDirectivesTest < Minitest::Test
  def setup
    @mock_flags   = OpenStruct.new(allow_ruby_eval: false)
    @mock_config  = OpenStruct.new(flags: @mock_flags)
    AIA.stubs(:config).returns(@mock_config)

    @mock_turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(@mock_turn_state)

    @instance = AIA::ExecutionDirectives.new
  end

  # ---------------------------------------------------------------------------
  # /ruby directive — guarded by allow_ruby_eval flag
  # ---------------------------------------------------------------------------

  def test_ruby_returns_error_when_allow_ruby_eval_not_set
    @mock_flags.allow_ruby_eval = false
    result = @instance.ruby(['1 + 1'])
    assert_match(/allow_ruby_eval/, result)
    refute_equal '2', result
  end

  def test_ruby_evaluates_code_when_allowed
    @mock_flags.allow_ruby_eval = true
    result = @instance.ruby(['1 + 1'])
    assert_equal '2', result
  end

  def test_ruby_returns_error_string_on_exception_when_allowed
    @mock_flags.allow_ruby_eval = true
    result = @instance.ruby(['raise "boom"'])
    assert_match(/boom/, result)
  end

  # ---------------------------------------------------------------------------
  # Mode-setting directives — set AIA.turn_state flags
  # ---------------------------------------------------------------------------

  def test_concurrent_sets_turn_state_flag
    @instance.concurrent([])
    assert_equal true, AIA.turn_state.force_concurrent_mcp
  end

  def test_verify_sets_turn_state_flag
    @instance.verify([])
    assert_equal true, AIA.turn_state.force_verify
  end

  def test_decompose_sets_turn_state_flag
    @instance.decompose([])
    assert_equal true, AIA.turn_state.force_decompose
  end

  def test_debate_sets_turn_state_flag
    @instance.debate([])
    assert_equal true, AIA.turn_state.force_debate
  end

  def test_delegate_sets_turn_state_flag
    @instance.delegate([])
    assert_equal true, AIA.turn_state.force_delegate
  end

  def test_spawn_sets_flag_and_specialist_type
    @instance.spawn(['mysql-expert'])
    assert_equal true,          AIA.turn_state.force_spawn
    assert_equal 'mysql-expert', AIA.turn_state.spawn_type
  end

  def test_orchestrate_sets_turn_state_flag
    @instance.orchestrate([])
    assert_equal true, AIA.turn_state.force_orchestrate
  end
end
