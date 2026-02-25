# frozen_string_literal: true
# test/aia/task_coordinator_test.rb

require_relative '../test_helper'

class TaskCoordinatorTest < Minitest::Test
  def setup
    @mock_db = mock('database')
    @mock_db.stubs(:connect)

    @mock_bridge = mock('bridge')
    @mock_bridge.stubs(:available?).returns(true)
    @mock_bridge.stubs(:db).returns(@mock_db)

    # Stub private method access
    AIA::TrakFlowBridge.stubs(:new).returns(@mock_bridge)

    @coordinator = AIA::TaskCoordinator.new(bridge: @mock_bridge)
  end

  def test_available_delegates_to_bridge
    assert @coordinator.available?
  end

  def test_unavailable_when_bridge_unavailable
    @mock_bridge.stubs(:available?).returns(false)
    coordinator = AIA::TaskCoordinator.new(bridge: @mock_bridge)
    refute coordinator.available?
  end

  def test_create_task_basic
    task = mock_task(id: "tf-abc1", title: "Test task")

    @mock_db.expects(:create_task).with(instance_of(TrakFlow::Models::Task)).returns(task)
    @mock_db.expects(:add_label).with(instance_of(TrakFlow::Models::Label)).once

    result = @coordinator.create_task("Test task", creator: "alice")
    assert_equal "tf-abc1", result.id
  end

  def test_create_task_with_assignee
    task = mock_task(id: "tf-abc2", title: "Assigned task", assignee: "bob")

    @mock_db.expects(:create_task).returns(task)
    @mock_db.expects(:add_label).at_least_once

    result = @coordinator.create_task("Assigned task", assignee: "bob")
    assert_equal "bob", result.assignee
  end

  def test_create_task_with_labels
    task = mock_task(id: "tf-abc3", title: "Labeled task")

    @mock_db.expects(:create_task).returns(task)
    # creator label + 2 custom labels = 3
    @mock_db.expects(:add_label).times(3)

    @coordinator.create_task("Labeled task", labels: ["domain:code", "priority:high"])
  end

  def test_create_task_with_blocked_by
    task = mock_task(id: "tf-abc4", title: "Blocked task")

    @mock_db.expects(:create_task).returns(task)
    @mock_db.expects(:add_label).once
    @mock_db.expects(:add_dependency).with(instance_of(TrakFlow::Models::Dependency)).twice

    @coordinator.create_task("Blocked task", blocked_by: ["tf-001", "tf-002"])
  end

  def test_create_task_with_parent_id
    task = mock_task(id: "tf-abc5", title: "Child task")

    @mock_db.expects(:create_task).returns(task)
    @mock_db.expects(:add_label).once
    @mock_db.expects(:add_dependency).with { |dep|
      dep.is_a?(TrakFlow::Models::Dependency) &&
        dep.source_id == "tf-parent" &&
        dep.target_id == "tf-abc5" &&
        dep.type == "parent-child"
    }.once

    @coordinator.create_task("Child task", parent_id: "tf-parent")
  end

  def test_create_task_returns_nil_when_unavailable
    @mock_bridge.stubs(:available?).returns(false)
    coordinator = AIA::TaskCoordinator.new(bridge: @mock_bridge)
    assert_nil coordinator.create_task("Test")
  end

  def test_create_plan
    plan = mock_task(id: "tf-plan1", title: "My plan", plan: true)
    step1 = mock_task(id: "tf-s1", title: "Step 1")
    step2 = mock_task(id: "tf-s2", title: "Step 2")

    @mock_db.expects(:create_task).returns(plan)
    @mock_db.expects(:add_label).once  # creator label
    @mock_db.expects(:create_child_task).with("tf-plan1", has_entry(title: "Step 1")).returns(step1)
    @mock_db.expects(:create_child_task).with("tf-plan1", has_entry(title: "Step 2")).returns(step2)
    @mock_db.expects(:add_dependency).once  # step1 blocks step2

    result = @coordinator.create_plan("My plan", steps: [
      { title: "Step 1", assignee: "alice" },
      { title: "Step 2", assignee: "bob" }
    ])

    assert_equal plan, result[:plan]
    assert_equal 2, result[:steps].size
  end

  def test_ready_tasks_all
    tasks = [mock_task(id: "tf-r1"), mock_task(id: "tf-r2")]
    @mock_db.expects(:ready_tasks).returns(tasks)

    result = @coordinator.ready_tasks
    assert_equal 2, result.size
  end

  def test_ready_tasks_filtered_by_assignee
    t1 = mock_task(id: "tf-r1", assignee: "alice")
    t2 = mock_task(id: "tf-r2", assignee: "bob")
    @mock_db.expects(:ready_tasks).returns([t1, t2])

    result = @coordinator.ready_tasks(robot_name: "alice")
    assert_equal 1, result.size
    assert_equal "alice", result.first.assignee
  end

  def test_ready_tasks_empty_when_unavailable
    @mock_bridge.stubs(:available?).returns(false)
    coordinator = AIA::TaskCoordinator.new(bridge: @mock_bridge)
    assert_equal [], coordinator.ready_tasks
  end

  def test_claim_task
    task = mock_task(id: "tf-c1", status: "open")
    task.expects(:status=).with("in_progress")
    task.expects(:assignee=).with("alice")
    task.expects(:append_trace).with("claimed", "Claimed by alice")

    @mock_db.expects(:find_task).with("tf-c1").returns(task)
    @mock_db.expects(:update_task).with(task)

    @coordinator.claim_task("tf-c1", "alice")
  end

  def test_claim_task_not_found
    @mock_db.expects(:find_task).with("tf-missing").returns(nil)
    @mock_db.expects(:update_task).never

    @coordinator.claim_task("tf-missing", "alice")
  end

  def test_complete_task
    task = mock_task(id: "tf-d1", status: "in_progress")
    task.expects(:close!).with(reason: "All done")

    @mock_db.expects(:find_task).with("tf-d1").returns(task)
    @mock_db.expects(:add_comment).with(instance_of(TrakFlow::Models::Comment))
    @mock_db.expects(:update_task).with(task)

    @coordinator.complete_task("tf-d1", result: "All done", robot_name: "alice")
  end

  def test_block_task
    task = mock_task(id: "tf-b1", status: "in_progress")
    task.expects(:status=).with("blocked")
    task.expects(:append_trace).with("blocked", "alice: API down")

    @mock_db.expects(:find_task).with("tf-b1").returns(task)
    @mock_db.expects(:update_task).with(task)

    @coordinator.block_task("tf-b1", reason: "API down", robot_name: "alice")
  end

  def test_status_summary
    open_task = mock_task(id: "tf-1", assignee: "alice", status: "open")
    open_task.stubs(:open?).returns(true)
    open_task.stubs(:in_progress?).returns(false)
    open_task.stubs(:closed?).returns(false)

    done_task = mock_task(id: "tf-2", assignee: "alice", status: "closed")
    done_task.stubs(:open?).returns(false)
    done_task.stubs(:in_progress?).returns(false)
    done_task.stubs(:closed?).returns(true)

    unassigned = mock_task(id: "tf-3", assignee: nil, status: "open")

    @mock_db.expects(:list_tasks).with({}).returns([open_task, done_task, unassigned])
    @mock_db.expects(:ready_tasks).returns([open_task])
    @mock_db.expects(:blocked_tasks).returns([])

    summary = @coordinator.status_summary
    assert_includes summary, "Task Board"
    assert_includes summary, "alice: 1 open, 1 done"
    assert_includes summary, "unassigned: 1"
  end

  def test_status_summary_returns_nil_when_unavailable
    @mock_bridge.stubs(:available?).returns(false)
    coordinator = AIA::TaskCoordinator.new(bridge: @mock_bridge)
    assert_nil coordinator.status_summary
  end

  private

  def mock_task(id: "tf-test", title: "Test", status: "open",
                assignee: nil, plan: false)
    task = OpenStruct.new(
      id: id, title: title, status: status,
      assignee: assignee, plan: plan
    )
    task.define_singleton_method(:open?) { status == "open" }
    task.define_singleton_method(:in_progress?) { status == "in_progress" }
    task.define_singleton_method(:closed?) { status == "closed" }
    task
  end
end
