# frozen_string_literal: true
# test/aia/task_executor_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class TaskExecutorTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, debug: false),
      models: [OpenStruct.new(name: 'gpt-4o-mini')]
    )
    AIA.stubs(:config).returns(@config)
  end

  def build_coordinator(task_id: "tf-t1")
    coordinator = mock('coordinator')
    task = OpenStruct.new(id: task_id)
    coordinator.stubs(:claim_task)
    coordinator.stubs(:complete_task)
    [coordinator, task]
  end

  def build_robot(name: "Alice", reply: "Task done")
    robot = mock(name.downcase)
    robot.stubs(:name).returns(name)
    robot.stubs(:run).returns(OpenStruct.new(reply: reply))
    robot
  end

  def test_execute_claims_and_completes_task
    coordinator, task = build_coordinator
    robot = build_robot

    coordinator.expects(:claim_task).with("tf-t1", "Alice")
    coordinator.expects(:complete_task).with("tf-t1", result: anything, robot_name: "Alice")

    executor = AIA::TaskExecutor.new(task_coordinator: coordinator)
    executor.execute(task, robot, { title: "Do work" }, "Original prompt", [])
  end

  def test_execute_returns_robot_content
    coordinator, task = build_coordinator
    robot = build_robot(reply: "Expert analysis")

    executor = AIA::TaskExecutor.new(task_coordinator: coordinator)
    result = executor.execute(task, robot, { title: "Analyze" }, "Prompt", [])

    assert_equal "Expert analysis", result
  end

  def test_execute_includes_prior_results_in_context
    coordinator, task = build_coordinator

    received_context = nil
    robot = mock('robot')
    robot.stubs(:name).returns("Bob")
    robot.stubs(:run).with { |ctx, **| received_context = ctx; true }.returns(OpenStruct.new(reply: "Done"))

    executor = AIA::TaskExecutor.new(task_coordinator: coordinator)
    prior = [{ robot: "Alice", task: "Research", content: "Alice's findings" }]
    executor.execute(task, robot, { title: "Synthesize" }, "Original", prior)

    assert_includes received_context, "Alice's findings"
    assert_includes received_context, "Prior work"
  end

  def test_execute_without_prior_results
    coordinator, task = build_coordinator

    received_context = nil
    robot = mock('robot')
    robot.stubs(:name).returns("Alice")
    robot.stubs(:run).with { |ctx, **| received_context = ctx; true }.returns(OpenStruct.new(reply: "Done"))

    executor = AIA::TaskExecutor.new(task_coordinator: coordinator)
    executor.execute(task, robot, { title: "First task" }, "Original prompt", [])

    assert_includes received_context, "Original prompt"
    refute_includes received_context, "Prior work"
  end
end
