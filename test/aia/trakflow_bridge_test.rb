# frozen_string_literal: true
# test/aia/trakflow_bridge_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class TrakFlowBridgeTest < Minitest::Test
  def setup
    @mock_db = mock('database')
  end

  # =========================================================================
  # available? tests
  # =========================================================================

  def test_available_returns_false_when_not_initialized
    TrakFlow.stubs(:initialized?).returns(false)

    bridge = AIA::TrakFlowBridge.new

    refute bridge.available?
  end

  def test_available_returns_true_when_initialized_and_connected
    stub_connected_bridge

    bridge = AIA::TrakFlowBridge.new

    assert bridge.available?
  end

  def test_available_returns_false_when_database_connect_fails
    TrakFlow.stubs(:initialized?).returns(true)
    TrakFlow.stubs(:database_path).returns("/tmp/nonexistent.db")
    TrakFlow::Storage::Database.stubs(:new).raises(StandardError, "connect failed")

    bridge = AIA::TrakFlowBridge.new

    refute bridge.available?
  end

  # =========================================================================
  # Returns nil when unavailable
  # =========================================================================

  def test_create_plan_from_pipeline_returns_nil_when_unavailable
    TrakFlow.stubs(:initialized?).returns(false)
    bridge = AIA::TrakFlowBridge.new

    assert_nil bridge.create_plan_from_pipeline(['a', 'b'])
  end

  def test_check_ready_tasks_returns_nil_when_unavailable
    TrakFlow.stubs(:initialized?).returns(false)
    bridge = AIA::TrakFlowBridge.new

    assert_nil bridge.check_ready_tasks
  end

  def test_project_summary_returns_nil_when_unavailable
    TrakFlow.stubs(:initialized?).returns(false)
    bridge = AIA::TrakFlowBridge.new

    assert_nil bridge.project_summary
  end

  def test_create_task_returns_nil_when_unavailable
    TrakFlow.stubs(:initialized?).returns(false)
    bridge = AIA::TrakFlowBridge.new

    assert_nil bridge.create_task("Test task")
  end

  def test_update_step_status_does_nothing_when_unavailable
    TrakFlow.stubs(:initialized?).returns(false)
    bridge = AIA::TrakFlowBridge.new

    # Should not raise
    bridge.update_step_status("step1", :started)
  end

  # =========================================================================
  # create_task
  # =========================================================================

  def test_create_task_creates_task_in_database
    bridge = stub_connected_bridge
    mock_task = OpenStruct.new(id: "tf-abc123", title: "Deploy feature")

    @mock_db.expects(:create_task).with { |t| t.title == "Deploy feature" }.returns(mock_task)

    result = bridge.create_task("Deploy feature")

    assert_includes result, "tf-abc123"
    assert_includes result, "Deploy feature"
  end

  def test_create_task_attaches_labels
    bridge = stub_connected_bridge
    mock_task = OpenStruct.new(id: "tf-abc123", title: "Test")

    @mock_db.stubs(:create_task).returns(mock_task)
    @mock_db.expects(:add_label).twice

    bridge.create_task("Test", labels: ["backend", "priority:high"])
  end

  # =========================================================================
  # check_ready_tasks
  # =========================================================================

  def test_check_ready_tasks_returns_formatted_list
    bridge = stub_connected_bridge

    tasks = [
      OpenStruct.new(id: "tf-aaa", title: "First task", status: "open"),
      OpenStruct.new(id: "tf-bbb", title: "Second task", status: "open")
    ]
    @mock_db.stubs(:ready_tasks).returns(tasks)

    result = bridge.check_ready_tasks

    assert_includes result, "Ready tasks (2)"
    assert_includes result, "First task"
    assert_includes result, "Second task"
  end

  def test_check_ready_tasks_returns_nil_when_no_ready_tasks
    bridge = stub_connected_bridge
    @mock_db.stubs(:ready_tasks).returns([])

    assert_nil bridge.check_ready_tasks
  end

  # =========================================================================
  # project_summary
  # =========================================================================

  def test_project_summary_returns_status_counts
    bridge = stub_connected_bridge

    tasks = [
      OpenStruct.new(status: "open"),
      OpenStruct.new(status: "open"),
      OpenStruct.new(status: "in_progress"),
      OpenStruct.new(status: "closed")
    ]
    @mock_db.stubs(:list_tasks).with({}).returns(tasks)
    @mock_db.stubs(:ready_tasks).returns([])

    result = bridge.project_summary

    assert_includes result, "4 tasks"
    assert_includes result, "open: 2"
    assert_includes result, "in_progress: 1"
    assert_includes result, "closed: 1"
  end

  # =========================================================================
  # update_step_status
  # =========================================================================

  def test_update_step_status_sets_in_progress
    bridge = stub_connected_bridge
    task = TrakFlow::Models::Task.new(title: "my_step", status: "open")

    @mock_db.stubs(:list_tasks).with(title: "my_step").returns([task])
    @mock_db.expects(:update_task).with { |t| t.status == "in_progress" }

    bridge.update_step_status("my_step", :started)
  end

  def test_update_step_status_closes_on_completed
    bridge = stub_connected_bridge
    task = TrakFlow::Models::Task.new(title: "my_step", status: "in_progress")

    @mock_db.stubs(:list_tasks).with(title: "my_step").returns([task])
    @mock_db.expects(:update_task).with { |t| t.status == "closed" }

    bridge.update_step_status("my_step", :completed)
  end

  def test_update_step_status_blocks_on_failed
    bridge = stub_connected_bridge
    task = TrakFlow::Models::Task.new(title: "my_step", status: "in_progress")

    @mock_db.stubs(:list_tasks).with(title: "my_step").returns([task])
    @mock_db.expects(:update_task).with { |t| t.status == "blocked" }

    bridge.update_step_status("my_step", :failed, reason: "timeout")
  end

  def test_update_step_status_ignores_missing_task
    bridge = stub_connected_bridge
    @mock_db.stubs(:list_tasks).returns([])

    # Should not raise or call update
    bridge.update_step_status("nonexistent", :started)
  end

  # =========================================================================
  # create_plan_from_pipeline
  # =========================================================================

  def test_create_plan_from_pipeline_creates_plan_with_steps
    bridge = stub_connected_bridge

    mock_plan = OpenStruct.new(id: "tf-plan1")
    step1 = OpenStruct.new(id: "tf-step1")
    step2 = OpenStruct.new(id: "tf-step2")

    @mock_db.expects(:create_task).with { |t| t.plan == true }.returns(mock_plan)
    @mock_db.expects(:create_child_task).with(mock_plan.id, has_entry(:title, "Step 1: prompt_a")).returns(step1)
    @mock_db.expects(:create_child_task).with(mock_plan.id, has_entry(:title, "Step 2: prompt_b")).returns(step2)
    @mock_db.expects(:add_dependency).with { |d| d.source_id == step1.id && d.target_id == step2.id }

    result = bridge.create_plan_from_pipeline(['prompt_a', 'prompt_b'])

    assert_includes result, "Pipeline"
    assert_includes result, "2 steps"
  end

  private

  # Stub a bridge with a connected mock database.
  def stub_connected_bridge
    TrakFlow.stubs(:initialized?).returns(true)
    TrakFlow.stubs(:database_path).returns("/tmp/test_tf.db")
    @mock_db.stubs(:connect)
    TrakFlow::Storage::Database.stubs(:new).returns(@mock_db)

    AIA::TrakFlowBridge.new
  end
end
