# frozen_string_literal: true
# test/aia/debate_handler_test.rb

require_relative '../test_helper'

class DebateHandlerTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, debug: false, verbose: false),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      mcp_servers: []
    )
    AIA.stubs(:config).returns(@config)
    @turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(@turn_state)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_ai_response)
    @ui.stubs(:display_separator)

    @tracker = mock('session_tracker')
    @tracker.stubs(:record_turn)
  end

  def test_returns_nil_for_single_robot
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)

    handler = AIA::DebateHandler.new(
      robot: robot, ui_presenter: @ui, tracker: @tracker
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "test prompt"))
  end

  def test_returns_nil_for_network_with_one_robot
    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    robot = mock('robot')
    network.stubs(:robots).returns({ a: robot })
    robot.stubs(:values).returns([robot])
    network.robots.stubs(:values).returns([robot])

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "test"))
  end

  def test_debate_runs_multiple_rounds
    robot_a = build_mock_robot("Alice", "Alice's take on this topic.")
    robot_b = build_mock_robot("Bob", "CONVERGED: I agree with Alice.")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Discuss AI safety"))

    assert_includes result, "Alice"
    assert_includes result, "Bob"
    assert_includes result, "Round 1"
  end

  def test_debate_converges_when_converged_keyword_found
    call_count = 0

    robot_a = mock('robot_a')
    robot_a.stubs(:name).returns("Alice")
    robot_a.stubs(:with_bus)
    robot_a.expects(:run).at_least_once.returns(
      OpenStruct.new(reply: "My position is X.")
    )

    robot_b = mock('robot_b')
    robot_b.stubs(:name).returns("Bob")
    robot_b.stubs(:with_bus)
    robot_b.expects(:run).at_least_once.returns(
      OpenStruct.new(reply: "CONVERGED: I agree completely.")
    )

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Topic"))

    # Should converge after round 1 since Bob says CONVERGED
    assert_includes result, "Round 1"
    refute_includes result, "Round 2"
  end

  def test_debate_writes_to_memory_when_available
    memory = mock('memory')
    memory.stubs(:current_writer=)
    memory.stubs(:set)

    robot_a = build_mock_robot("Alice", "Position A")
    robot_b = build_mock_robot("Bob", "CONVERGED")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(true)
    network.stubs(:memory).returns(memory)

    memory.expects(:current_writer=).at_least_once
    memory.expects(:set).at_least_once

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    handler.handle(AIA::HandlerContext.new(prompt: "Topic"))
  end

  def test_force_debate_flag
    @turn_state.force_debate = true
    assert @turn_state.force_debate
    @turn_state.clear!
    refute @turn_state.force_debate
  end

  private

  def build_mock_robot(name, reply_text)
    robot = mock(name.downcase)
    robot.stubs(:name).returns(name)
    robot.stubs(:with_bus)
    robot.stubs(:run).returns(OpenStruct.new(reply: reply_text))
    robot
  end
end
