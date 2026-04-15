# frozen_string_literal: true
# test/aia/turn_state_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class TurnStateTest < Minitest::Test
  def setup
    @ts = AIA::TurnState.new
  end

  # ---------------------------------------------------------------------------
  # Initial state
  # ---------------------------------------------------------------------------

  def test_all_flags_false_after_initialize
    AIA::TurnState::EXCLUSIVE_MODES.each do |mode|
      flag = :"force_#{mode == :concurrent_mcp ? 'concurrent_mcp' : mode}"
      refute @ts.send(flag), "#{flag} should be false on init"
    end
  end

  def test_spawn_type_nil_after_initialize
    assert_nil @ts.spawn_type
  end

  def test_active_mode_nil_when_no_flags_set
    assert_nil @ts.active_mode
  end

  # ---------------------------------------------------------------------------
  # request — happy path
  # ---------------------------------------------------------------------------

  def test_request_verify_sets_force_verify
    @ts.request(:verify)
    assert @ts.force_verify
  end

  def test_request_decompose_sets_force_decompose
    @ts.request(:decompose)
    assert @ts.force_decompose
  end

  def test_request_concurrent_mcp_sets_flag
    @ts.request(:concurrent_mcp)
    assert @ts.force_concurrent_mcp
  end

  def test_request_debate_sets_force_debate
    @ts.request(:debate)
    assert @ts.force_debate
  end

  def test_request_delegate_sets_force_delegate
    @ts.request(:delegate)
    assert @ts.force_delegate
  end

  def test_request_spawn_sets_force_spawn
    @ts.request(:spawn)
    assert @ts.force_spawn
  end

  def test_request_spawn_with_type_sets_spawn_type
    @ts.request(:spawn, type: "security_expert")
    assert @ts.force_spawn
    assert_equal "security_expert", @ts.spawn_type
  end

  # ---------------------------------------------------------------------------
  # Mutual exclusion
  # ---------------------------------------------------------------------------

  def test_request_clears_previous_mode
    @ts.request(:verify)
    assert @ts.force_verify

    @ts.request(:debate)
    refute @ts.force_verify, "force_verify should be cleared after requesting :debate"
    assert @ts.force_debate
  end

  def test_only_one_exclusive_mode_active_at_a_time
    @ts.request(:verify)
    @ts.request(:spawn, type: "expert")

    active_flags = AIA::TurnState::EXCLUSIVE_MODES.count do |mode|
      flag = :"force_#{mode}"
      @ts.respond_to?(flag) && @ts.send(flag)
    end

    assert_equal 1, active_flags
    assert @ts.force_spawn
  end

  def test_request_spawn_clears_spawn_type_when_not_provided
    @ts.request(:spawn, type: "old_type")
    @ts.request(:verify)
    @ts.request(:spawn)
    assert_nil @ts.spawn_type
  end

  # ---------------------------------------------------------------------------
  # active_mode
  # ---------------------------------------------------------------------------

  def test_active_mode_returns_verify
    @ts.request(:verify)
    assert_equal :verify, @ts.active_mode
  end

  def test_active_mode_returns_decompose
    @ts.request(:decompose)
    assert_equal :decompose, @ts.active_mode
  end

  def test_active_mode_returns_concurrent_mcp
    @ts.request(:concurrent_mcp)
    assert_equal :concurrent_mcp, @ts.active_mode
  end

  def test_active_mode_returns_debate
    @ts.request(:debate)
    assert_equal :debate, @ts.active_mode
  end

  def test_active_mode_returns_delegate
    @ts.request(:delegate)
    assert_equal :delegate, @ts.active_mode
  end

  def test_active_mode_returns_spawn
    @ts.request(:spawn)
    assert_equal :spawn, @ts.active_mode
  end

  # ---------------------------------------------------------------------------
  # clear!
  # ---------------------------------------------------------------------------

  def test_clear_resets_all_exclusive_flags
    @ts.request(:debate)
    @ts.clear!

    assert_nil @ts.active_mode
    refute @ts.force_debate
  end

  def test_clear_resets_spawn_type
    @ts.request(:spawn, type: "specialist")
    @ts.clear!
    assert_nil @ts.spawn_type
  end

  def test_clear_resets_active_mcp_servers
    @ts.active_mcp_servers = [:server_a]
    @ts.clear!
    assert_nil @ts.active_mcp_servers
  end


  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------

  def test_request_raises_for_unknown_mode
    err = assert_raises(ArgumentError) { @ts.request(:unknown_mode) }
    assert_match(/unknown_mode/, err.message)
  end

  def test_request_error_leaves_previous_mode_intact
    @ts.request(:verify)
    assert_raises(ArgumentError) { @ts.request(:bogus) }
    # After a failed request the state should not have been partially changed;
    # ArgumentError is raised before any mutation
    assert @ts.force_verify
  end

  # ---------------------------------------------------------------------------
  # EXCLUSIVE_MODES constant
  # ---------------------------------------------------------------------------

  def test_exclusive_modes_is_frozen
    assert AIA::TurnState::EXCLUSIVE_MODES.frozen?
  end

  def test_exclusive_modes_contains_expected_modes
    expected = %i[verify decompose concurrent_mcp debate delegate spawn orchestrate]
    assert_equal expected, AIA::TurnState::EXCLUSIVE_MODES
  end
end
