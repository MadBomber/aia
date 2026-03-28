# frozen_string_literal: true

# test/aia/special_mode_handler_test.rb
#
# Tests for SpecialModeHandler: TurnState flag dispatch for
# /verify, /decompose, /concurrent, /debate, /delegate, /spawn modes.

require_relative '../test_helper'
require_relative '../../lib/aia'

class SpecialModeHandlerTest < Minitest::Test
  def setup
    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_ai_response)
    @ui.stubs(:display_separator)

    @tracker = mock('tracker')
    @tracker.stubs(:record_turn)

    @rule_router = mock('rule_router')
    @rule_router.stubs(:decisions).returns(AIA::Decisions.new)

    @robot = mock('robot')
    @robot.stubs(:is_a?).returns(false)

    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o')],
      output: OpenStruct.new(file: nil),
      mcp_servers: []
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:task_coordinator).returns(nil)
    AIA.turn_state = AIA::TurnState.new

    @handler = AIA::SpecialModeHandler.new(
      robot: @robot,
      ui_presenter: @ui,
      tracker: @tracker,
      rule_router: @rule_router
    )
  end

  # --- handle returns false when no flags set ---

  def test_handle_returns_false_when_no_flags_set
    assert_equal false, @handler.handle("hello")
  end

  # --- force_verify ---

  def test_handle_dispatches_to_verification
    AIA.turn_state.force_verify = true

    # Stub VerificationNetwork.build to return a mock network
    network = mock('network')
    result = mock('result')
    result.stubs(:reply).returns('verified answer')

    network.stubs(:run).with("test prompt").returns(result)
    AIA::VerificationNetwork.stubs(:build).returns(network)
    @ui.stubs(:with_spinner).yields.returns(result)

    assert_equal true, @handler.handle("test prompt")
    assert_equal false, AIA.turn_state.force_verify
  end

  def test_verification_clears_flag
    AIA.turn_state.force_verify = true

    AIA::VerificationNetwork.stubs(:build).raises(StandardError.new("test error"))

    @handler.handle("test prompt")

    assert_equal false, AIA.turn_state.force_verify
  end

  # --- force_decompose ---

  def test_handle_dispatches_to_decomposition
    AIA.turn_state.force_decompose = true

    decomposer = mock('decomposer')
    decomposer.stubs(:decompose).returns(['subtask1', 'subtask2'])
    sub_result = mock('sub_result')
    sub_result.stubs(:reply).returns('sub answer')
    decomposer.stubs(:synthesize).returns(sub_result)

    AIA::PromptDecomposer.stubs(:new).returns(decomposer)
    @robot.stubs(:run).returns(sub_result)

    assert_equal true, @handler.handle("complex prompt")
    assert_equal false, AIA.turn_state.force_decompose
  end

  def test_decomposition_clears_flag
    AIA.turn_state.force_decompose = true

    decomposer = mock('decomposer')
    decomposer.stubs(:decompose).raises(StandardError.new("decompose error"))
    AIA::PromptDecomposer.stubs(:new).returns(decomposer)

    @handler.handle("test")

    assert_equal false, AIA.turn_state.force_decompose
  end

  def test_decomposition_returns_false_when_no_subtasks
    AIA.turn_state.force_decompose = true

    decomposer = mock('decomposer')
    decomposer.stubs(:decompose).returns([])
    AIA::PromptDecomposer.stubs(:new).returns(decomposer)

    assert_equal false, @handler.handle("simple prompt")
  end

  # --- force_concurrent_mcp ---

  def test_handle_dispatches_to_concurrent_mcp
    @config.mcp_servers = [{ name: 'a' }, { name: 'b' }]
    AIA.turn_state.force_concurrent_mcp = true

    discovery = mock('discovery')
    discovery.stubs(:discover).returns([{ name: 'a' }, { name: 'b' }])
    AIA::MCPDiscovery.stubs(:new).returns(discovery)

    grouper = mock('grouper')
    grouper.stubs(:group).returns([[{ name: 'a' }], [{ name: 'b' }]])
    AIA::MCPGrouper.stubs(:new).returns(grouper)

    network = mock('network')
    result = mock('result')
    result.stubs(:reply).returns('concurrent result')

    network.stubs(:run).with("test prompt").returns(result)
    AIA::RobotFactory.stubs(:build_concurrent_mcp_network).returns(network)
    @ui.stubs(:with_spinner).yields.returns(result)

    assert_equal true, @handler.handle("test prompt")
    assert_equal false, AIA.turn_state.force_concurrent_mcp
  end

  def test_concurrent_mcp_returns_false_with_single_server
    @config.mcp_servers = [{ name: 'a' }]
    AIA.turn_state.force_concurrent_mcp = true

    assert_equal false, @handler.handle("test")
  end

  # --- force_debate ---

  def test_handle_dispatches_to_debate
    AIA.turn_state.force_debate = true

    # DebateHandler returns content directly
    debate_handler = @handler.instance_variable_get(:@debate_handler)
    debate_handler.stubs(:handle).returns("debate result")

    assert_equal true, @handler.handle("debate topic")
    assert_equal false, AIA.turn_state.force_debate
  end

  def test_debate_returns_false_when_handler_returns_nil
    AIA.turn_state.force_debate = true

    debate_handler = @handler.instance_variable_get(:@debate_handler)
    debate_handler.stubs(:handle).returns(nil)

    assert_equal false, @handler.handle("debate topic")
  end

  def test_debate_clears_flag
    AIA.turn_state.force_debate = true

    debate_handler = @handler.instance_variable_get(:@debate_handler)
    debate_handler.stubs(:handle).raises(StandardError.new("debate error"))

    @handler.handle("topic")

    assert_equal false, AIA.turn_state.force_debate
  end

  # --- force_delegate ---

  def test_handle_dispatches_to_delegation
    AIA.turn_state.force_delegate = true

    delegate_handler = @handler.instance_variable_get(:@delegate_handler)
    delegate_handler.stubs(:handle).returns("delegation result")

    assert_equal true, @handler.handle("delegate task")
    assert_equal false, AIA.turn_state.force_delegate
  end

  def test_delegation_returns_false_when_handler_returns_nil
    AIA.turn_state.force_delegate = true

    delegate_handler = @handler.instance_variable_get(:@delegate_handler)
    delegate_handler.stubs(:handle).returns(nil)

    assert_equal false, @handler.handle("delegate task")
  end

  def test_delegation_clears_flag
    AIA.turn_state.force_delegate = true

    delegate_handler = @handler.instance_variable_get(:@delegate_handler)
    delegate_handler.stubs(:handle).raises(StandardError.new("delegate error"))

    @handler.handle("task")

    assert_equal false, AIA.turn_state.force_delegate
  end

  # --- force_spawn ---

  def test_handle_dispatches_to_spawn
    AIA.turn_state.force_spawn = true
    AIA.turn_state.spawn_type = 'security_expert'

    spawn_handler = @handler.instance_variable_get(:@spawn_handler)
    spawn_handler.stubs(:handle).returns("spawn result")

    assert_equal true, @handler.handle("spawn task")
    assert_equal false, AIA.turn_state.force_spawn
    assert_nil AIA.turn_state.spawn_type
  end

  def test_spawn_returns_false_when_handler_returns_nil
    AIA.turn_state.force_spawn = true
    AIA.turn_state.spawn_type = nil

    spawn_handler = @handler.instance_variable_get(:@spawn_handler)
    spawn_handler.stubs(:handle).returns(nil)

    assert_equal false, @handler.handle("spawn task")
  end

  def test_spawn_clears_flag_and_type
    AIA.turn_state.force_spawn = true
    AIA.turn_state.spawn_type = 'analyst'

    spawn_handler = @handler.instance_variable_get(:@spawn_handler)
    spawn_handler.stubs(:handle).raises(StandardError.new("spawn error"))

    @handler.handle("task")

    assert_equal false, AIA.turn_state.force_spawn
    assert_nil AIA.turn_state.spawn_type
  end

  # --- robot= writer ---

  def test_robot_writer_propagates_to_sub_handlers
    new_robot = mock('new_robot')
    new_robot.stubs(:is_a?).returns(false)

    @handler.robot = new_robot

    assert_equal new_robot, @handler.instance_variable_get(:@robot)
  end

  # --- Priority: verify > decompose > concurrent_mcp > debate > delegate > spawn ---

  def test_verify_takes_priority_over_decompose
    AIA.turn_state.force_verify = true
    AIA.turn_state.force_decompose = true

    network = mock('network')
    result = mock('result')
    result.stubs(:reply).returns('verified')

    network.stubs(:run).with("test").returns(result)
    AIA::VerificationNetwork.stubs(:build).returns(network)
    @ui.stubs(:with_spinner).yields.returns(result)

    assert_equal true, @handler.handle("test")
    assert_equal false, AIA.turn_state.force_verify
    # decompose was not cleared because verify was handled first
    assert_equal true, AIA.turn_state.force_decompose

    # Clean up
    AIA.turn_state.force_decompose = false
  end
end
