# frozen_string_literal: true
# test/aia/tools/task_board_tool_test.rb

require_relative '../../test_helper'

class TaskBoardToolTest < Minitest::Test
  def setup
    @coordinator = mock('coordinator')
    @coordinator.stubs(:available?).returns(true)
    AIA.stubs(:task_coordinator).returns(@coordinator)
  end

  def test_returns_unavailable_when_no_coordinator
    AIA.stubs(:task_coordinator).returns(nil)
    tool = AIA::TaskBoardTool.new

    result = tool.execute(action: "status")
    assert_includes result, "unavailable"
  end

  def test_create_action
    task = OpenStruct.new(id: "tf-abc1", title: "New task")
    @coordinator.expects(:create_task).with(
      "New task",
      assignee: "bob",
      labels: ["urgent"],
      blocked_by: [],
      creator: "alice"
    ).returns(task)

    tool = AIA::TaskBoardTool.new
    result = tool.execute(
      action: "create",
      title: "New task",
      assignee: "bob",
      labels: "urgent",
      _robot_name: "alice"
    )

    assert_includes result, "tf-abc1"
    assert_includes result, "New task"
  end

  def test_plan_action
    plan_result = { plan: OpenStruct.new(id: "tf-p1"), steps: [1, 2, 3] }
    @coordinator.expects(:create_plan).returns(plan_result)

    tool = AIA::TaskBoardTool.new
    result = tool.execute(
      action: "plan",
      title: "My plan",
      steps: '[{"title": "Step 1", "assignee": "alice"}]',
      _robot_name: "alice"
    )

    assert_includes result, "3 steps"
  end

  def test_plan_action_with_invalid_json
    tool = AIA::TaskBoardTool.new
    result = tool.execute(
      action: "plan",
      title: "Bad plan",
      steps: "not valid json",
      _robot_name: "alice"
    )

    assert_includes result, "Invalid steps JSON"
  end

  def test_ready_action
    tasks = [
      OpenStruct.new(id: "tf-r1", title: "Task A", assignee: "alice"),
      OpenStruct.new(id: "tf-r2", title: "Task B", assignee: nil)
    ]
    @coordinator.expects(:ready_tasks).with(robot_name: nil).returns(tasks)

    tool = AIA::TaskBoardTool.new
    result = tool.execute(action: "ready")

    assert_includes result, "tf-r1"
    assert_includes result, "Task A"
    assert_includes result, "tf-r2"
  end

  def test_ready_action_empty
    @coordinator.expects(:ready_tasks).returns([])

    tool = AIA::TaskBoardTool.new
    result = tool.execute(action: "ready")

    assert_equal "No ready tasks", result
  end

  def test_claim_action
    @coordinator.expects(:claim_task).with("tf-c1", "alice")

    tool = AIA::TaskBoardTool.new
    result = tool.execute(
      action: "claim", task_id: "tf-c1", _robot_name: "alice"
    )

    assert_includes result, "Claimed"
  end

  def test_complete_action
    @coordinator.expects(:complete_task).with(
      "tf-d1", result: "All done", robot_name: "alice"
    )

    tool = AIA::TaskBoardTool.new
    result = tool.execute(
      action: "complete", task_id: "tf-d1",
      result: "All done", _robot_name: "alice"
    )

    assert_includes result, "Completed"
  end

  def test_block_action
    @coordinator.expects(:block_task).with(
      "tf-b1", reason: "API down", robot_name: "alice"
    )

    tool = AIA::TaskBoardTool.new
    result = tool.execute(
      action: "block", task_id: "tf-b1",
      result: "API down", _robot_name: "alice"
    )

    assert_includes result, "Blocked"
  end

  def test_status_action
    @coordinator.expects(:status_summary).returns("Task Board (5 total)")

    tool = AIA::TaskBoardTool.new
    result = tool.execute(action: "status")

    assert_includes result, "Task Board"
  end

  def test_unknown_action
    tool = AIA::TaskBoardTool.new
    result = tool.execute(action: "unknown_action")

    assert_includes result, "Unknown action"
  end
end
