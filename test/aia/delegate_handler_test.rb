# frozen_string_literal: true
# test/aia/delegate_handler_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia/delegate_handler'
require_relative '../../lib/aia/task_decomposer'
require_relative '../../lib/aia/task_executor'

class DelegateHandlerTest < Minitest::Test
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

    handler = AIA::DelegateHandler.new(
      robot: robot, ui_presenter: @ui,
      tracker: @tracker, task_coordinator: nil
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "test"))
  end

  def test_returns_nil_when_coordinator_unavailable
    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(false)

    network = build_mock_network

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui,
      tracker: @tracker, task_coordinator: coordinator
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "test"))
  end

  def test_returns_nil_when_plan_cannot_be_parsed
    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)

    lead = mock('lead')
    lead.stubs(:name).returns("Alice")
    # Return something that isn't valid JSON
    lead.stubs(:run).returns(OpenStruct.new(reply: "I can't parse this"))

    robot_b = mock('robot_b')
    robot_b.stubs(:name).returns("Bob")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: lead, bob: robot_b })
    network.robots.stubs(:values).returns([lead, robot_b])

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui,
      tracker: @tracker, task_coordinator: coordinator
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "test"))
  end

  def test_delegates_and_executes_steps
    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)

    plan_json = '[{"title": "Research topic", "assignee": "Alice"}, {"title": "Write summary", "assignee": "Bob"}]'

    lead = mock('lead')
    lead.stubs(:name).returns("Alice")
    # First call: decomposition; subsequent calls: step execution
    lead.stubs(:run).returns(OpenStruct.new(reply: plan_json))
                    .then.returns(OpenStruct.new(reply: "Research results here"))

    robot_b = mock('robot_b')
    robot_b.stubs(:name).returns("Bob")
    robot_b.stubs(:run).returns(OpenStruct.new(reply: "Summary written"))

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: lead, bob: robot_b })
    network.robots.stubs(:values).returns([lead, robot_b])
    network.stubs(:respond_to?).with(:memory).returns(false)

    step1 = OpenStruct.new(id: "tf-s1")
    step2 = OpenStruct.new(id: "tf-s2")
    plan = OpenStruct.new(id: "tf-p1")

    coordinator.expects(:create_plan).returns({ plan: plan, steps: [step1, step2] })
    coordinator.expects(:claim_task).with("tf-s1", "Alice")
    coordinator.expects(:claim_task).with("tf-s2", "Bob")
    coordinator.expects(:complete_task).with("tf-s1", result: anything, robot_name: "Alice")
    coordinator.expects(:complete_task).with("tf-s2", result: anything, robot_name: "Bob")

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui,
      tracker: @tracker, task_coordinator: coordinator
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Research and summarize AI safety"))

    assert_includes result, "Step 1"
    assert_includes result, "Step 2"
    assert_includes result, "Alice"
    assert_includes result, "Bob"
  end

  def test_falls_back_to_first_robot_for_unknown_assignee
    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)

    plan_json = '[{"title": "Do work", "assignee": "NonExistent"}]'

    lead = mock('lead')
    lead.stubs(:name).returns("Alice")
    lead.stubs(:run).returns(OpenStruct.new(reply: plan_json))
                    .then.returns(OpenStruct.new(reply: "Done"))

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: lead })
    network.robots.stubs(:values).returns([lead])
    network.stubs(:respond_to?).with(:memory).returns(false)

    step1 = OpenStruct.new(id: "tf-s1")
    plan = OpenStruct.new(id: "tf-p1")

    coordinator.stubs(:create_plan).returns({ plan: plan, steps: [step1] })
    coordinator.stubs(:claim_task)
    coordinator.stubs(:complete_task)

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui,
      tracker: @tracker, task_coordinator: coordinator
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Do something"))
    # Should fall back to Alice (first robot)
    assert_includes result, "Alice"
  end

  def test_force_delegate_flag
    @turn_state.force_delegate = true
    assert @turn_state.force_delegate
    @turn_state.clear!
    refute @turn_state.force_delegate
  end

  private

  def build_mock_network
    robot = mock('robot')
    robot.stubs(:name).returns("Alice")

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: robot })
    network.robots.stubs(:values).returns([robot])
    network
  end
end
