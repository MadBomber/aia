# frozen_string_literal: true
# test/aia/trakflow_bridge_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class TrakFlowBridgeTest < Minitest::Test
  def setup
    @mock_robot = mock('robot')
  end

  def teardown
    super
  end

  def test_available_returns_false_with_nil_robot
    bridge = AIA::TrakFlowBridge.new(nil)

    refute bridge.available?
  end

  def test_available_returns_false_when_no_trak_flow_server
    trak_server = OpenStruct.new(name: 'some_other_server')
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(true)
    @mock_robot.stubs(:mcp_servers).returns([trak_server])

    bridge = AIA::TrakFlowBridge.new(@mock_robot)

    refute bridge.available?
  end

  def test_available_returns_true_when_trak_flow_server_present
    trak_server = OpenStruct.new(name: 'trak_flow')
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(true)
    @mock_robot.stubs(:respond_to?).with(:mcp_tools).returns(false)
    @mock_robot.stubs(:mcp_servers).returns([trak_server])

    bridge = AIA::TrakFlowBridge.new(@mock_robot)

    assert bridge.available?
  end

  def test_available_returns_true_via_mcp_tools_fallback
    mock_tool = OpenStruct.new(name: 'trak_flow_create_task')
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(false)
    @mock_robot.stubs(:respond_to?).with(:mcp_tools).returns(true)
    @mock_robot.stubs(:mcp_tools).returns([mock_tool])

    bridge = AIA::TrakFlowBridge.new(@mock_robot)

    assert bridge.available?
  end

  def test_available_returns_false_when_robot_has_no_mcp_methods
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(false)
    @mock_robot.stubs(:respond_to?).with(:mcp_tools).returns(false)

    bridge = AIA::TrakFlowBridge.new(@mock_robot)

    refute bridge.available?
  end

  def test_create_plan_from_pipeline_returns_nil_when_unavailable
    bridge = AIA::TrakFlowBridge.new(nil)

    result = bridge.create_plan_from_pipeline(['prompt_a', 'prompt_b'])

    assert_nil result
  end

  def test_check_ready_tasks_returns_nil_when_unavailable
    bridge = AIA::TrakFlowBridge.new(nil)

    result = bridge.check_ready_tasks

    assert_nil result
  end

  def test_project_summary_returns_nil_when_unavailable
    bridge = AIA::TrakFlowBridge.new(nil)

    result = bridge.project_summary

    assert_nil result
  end

  def test_create_task_returns_nil_when_unavailable
    bridge = AIA::TrakFlowBridge.new(nil)

    result = bridge.create_task("Test task")

    assert_nil result
  end

  def test_create_plan_from_pipeline_calls_robot_run_when_available
    trak_server = OpenStruct.new(name: 'trak_flow')
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(true)
    @mock_robot.stubs(:respond_to?).with(:mcp_tools).returns(false)
    @mock_robot.stubs(:mcp_servers).returns([trak_server])

    mock_result = OpenStruct.new(reply: "Plan created successfully")
    @mock_robot.expects(:run).with(
      regexp_matches(/Create a TrakFlow plan/),
      mcp: :inherit, tools: :none
    ).returns(mock_result)

    bridge = AIA::TrakFlowBridge.new(@mock_robot)
    result = bridge.create_plan_from_pipeline(['step1', 'step2'])

    assert_equal "Plan created successfully", result
  end

  def test_check_ready_tasks_calls_robot_run_when_available
    trak_server = OpenStruct.new(name: 'trak_flow')
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(true)
    @mock_robot.stubs(:respond_to?).with(:mcp_tools).returns(false)
    @mock_robot.stubs(:mcp_servers).returns([trak_server])

    mock_result = OpenStruct.new(reply: "2 tasks ready")
    @mock_robot.expects(:run).with(
      regexp_matches(/List all ready TrakFlow tasks/),
      mcp: :inherit, tools: :none
    ).returns(mock_result)

    bridge = AIA::TrakFlowBridge.new(@mock_robot)
    result = bridge.check_ready_tasks

    assert_equal "2 tasks ready", result
  end

  def test_update_step_status_does_nothing_when_unavailable
    bridge = AIA::TrakFlowBridge.new(nil)

    # Should not raise
    bridge.update_step_status("step1", :started)
  end

  def test_update_step_status_sends_start_command
    trak_server = OpenStruct.new(name: 'trak_flow')
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(true)
    @mock_robot.stubs(:respond_to?).with(:mcp_tools).returns(false)
    @mock_robot.stubs(:mcp_servers).returns([trak_server])

    mock_result = OpenStruct.new(reply: "Started")
    @mock_robot.expects(:run).with(
      regexp_matches(/Start TrakFlow task 'my_step'/),
      mcp: :inherit, tools: :none
    ).returns(mock_result)

    bridge = AIA::TrakFlowBridge.new(@mock_robot)
    bridge.update_step_status("my_step", :started)
  end

  def test_create_task_calls_robot_run_when_available
    trak_server = OpenStruct.new(name: 'trak_flow')
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).returns(true)
    @mock_robot.stubs(:respond_to?).with(:mcp_tools).returns(false)
    @mock_robot.stubs(:mcp_servers).returns([trak_server])

    mock_result = OpenStruct.new(reply: "Task created")
    @mock_robot.expects(:run).with(
      regexp_matches(/Create a TrakFlow task titled 'Deploy feature'/),
      mcp: :inherit, tools: :none
    ).returns(mock_result)

    bridge = AIA::TrakFlowBridge.new(@mock_robot)
    result = bridge.create_task("Deploy feature")

    assert_equal "Task created", result
  end

  def test_available_returns_false_when_exception_raised
    @mock_robot.stubs(:respond_to?).with(:mcp_servers).raises(StandardError, "connection error")

    bridge = AIA::TrakFlowBridge.new(@mock_robot)

    refute bridge.available?
  end
end
