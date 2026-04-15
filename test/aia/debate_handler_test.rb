# frozen_string_literal: true
# test/aia/debate_handler_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia/debate_handler'

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

  def test_debate_requires_min_rounds_before_convergence
    # CONVERGED keyword alone no longer ends the debate in round 1.
    # MIN_ROUNDS = 2 means the debate must run at least 2 rounds.
    robot_a = mock('robot_a')
    robot_a.stubs(:name).returns("Alice")
    robot_a.stubs(:with_bus)
    robot_a.stubs(:run).returns(OpenStruct.new(reply: "My position is X."))

    robot_b = mock('robot_b')
    robot_b.stubs(:name).returns("Bob")
    robot_b.stubs(:with_bus)
    robot_b.stubs(:run).returns(OpenStruct.new(reply: "CONVERGED: I agree completely, totally different take."))

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Topic"))

    # Must run at least 2 rounds regardless of CONVERGED keyword in round 1
    assert_includes result, "Round 1"
    assert_includes result, "Round 2"
  end

  def test_debate_converges_on_high_similarity_after_min_rounds
    # Identical responses in both rounds → similarity = 1.0 → converge after round 2
    same_reply = "The answer is clearly forty-two and we all agree."

    robot_a = build_mock_robot("Alice", same_reply)
    robot_b = build_mock_robot("Bob", same_reply)

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Meaning of life?"))

    assert_includes result, "Round 1"
    assert_includes result, "Round 2"
    refute_includes result, "Round 3"
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

  def test_failed_robot_produces_failed_response_not_exception
    robot_a = mock('robot_a')
    robot_a.stubs(:name).returns("Alice")
    robot_a.stubs(:with_bus)
    robot_a.stubs(:run).raises(RuntimeError, "model timeout")

    robot_b = build_mock_robot("Bob", "Bob's thoughtful reply.")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Discuss AI"))
    assert_includes result, "[FAILED]"
    assert_includes result, "Alice"
  end

  def test_debate_continues_when_one_robot_fails
    robot_a = mock('robot_a')
    robot_a.stubs(:name).returns("Alice")
    robot_a.stubs(:with_bus)
    robot_a.stubs(:run).raises(RuntimeError, "timeout")

    robot_b = build_mock_robot("Bob", "Bob's substantive response.")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Topic"))
    assert_includes result, "Bob's substantive response."
  end

  def test_debate_raises_debate_error_when_all_robots_fail
    robot_a = mock('robot_a')
    robot_a.stubs(:name).returns("Alice")
    robot_a.stubs(:with_bus)
    robot_a.stubs(:run).raises(RuntimeError, "Alice failed")

    robot_b = mock('robot_b')
    robot_b.stubs(:name).returns("Bob")
    robot_b.stubs(:with_bus)
    robot_b.stubs(:run).raises(RuntimeError, "Bob failed")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    assert_raises(AIA::DebateError) do
      handler.handle(AIA::HandlerContext.new(prompt: "Topic"))
    end
  end

  def test_convergence_check_treats_failed_response_as_empty_string
    # Alice always fails; Bob always gives identical replies.
    # converged? must treat FailedResponse as "" and not crash.
    robot_a = mock('robot_a')
    robot_a.stubs(:name).returns("Alice")
    robot_a.stubs(:with_bus)
    robot_a.stubs(:run).raises(RuntimeError, "Alice failed")

    same_reply = "The definitive answer that never changes at all."
    robot_b = build_mock_robot("Bob", same_reply)

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Topic"))
    assert_kind_of String, result
  end

  def test_format_rounds_renders_failed_response_with_marker
    robot_a = mock('robot_a')
    robot_a.stubs(:name).returns("Alice")
    robot_a.stubs(:with_bus)
    robot_a.stubs(:run).raises(RuntimeError, "connection refused")

    robot_b = build_mock_robot("Bob", "Bob succeeded with a clear answer.")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot_a, bob: robot_b })
    network.robots.stubs(:values).returns([robot_a, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    handler = AIA::DebateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Topic"))
    assert_includes result, "[FAILED]"
    assert_includes result, "connection refused"
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
