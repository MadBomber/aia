# frozen_string_literal: true
# test/aia/streaming_runner_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia/streaming_runner'

class StreamingRunnerTest < Minitest::Test
  def setup
    @result = mock('result')

    # Stub TTY::Spinner BEFORE creating the runner because the constructor
    # calls TTY::Spinner.new immediately in initialize.
    @spinner = mock('spinner')
    @spinner.stubs(:reset)
    @spinner.stubs(:update)
    @spinner.stubs(:auto_spin)
    @spinner.stubs(:stop)
    TTY::Spinner.stubs(:new).returns(@spinner)

    @runner = AIA::StreamingRunner.new
  end

  def test_run_returns_three_element_array
    robot = build_non_network_robot
    robot.stubs(:run).returns(@result)
    out = @runner.run(robot, "hello")
    assert_equal 3, out.size
  end

  def test_run_returns_result_as_first_element
    robot = build_non_network_robot
    robot.stubs(:run).returns(@result)
    result, _content, _elapsed = @runner.run(robot, "hello")
    assert_same @result, result
  end

  def test_run_returns_nil_content_when_no_streaming_chunks
    robot = build_non_network_robot
    robot.stubs(:run).returns(@result)  # no yield — nothing streamed
    _result, content, _elapsed = @runner.run(robot, "hello")
    assert_nil content
  end

  def test_run_returns_elapsed_as_float
    robot = build_non_network_robot
    robot.stubs(:run).returns(@result)
    _result, _content, elapsed = @runner.run(robot, "hello")
    assert_kind_of Float, elapsed
    assert elapsed >= 0.0
  end

  def test_run_uses_inherit_when_tools_nil
    robot = build_non_network_robot
    robot.expects(:run).with("hello", mcp: :inherit, tools: :inherit).returns(@result)
    @runner.run(robot, "hello", tools: nil)
  end

  def test_run_uses_inherit_when_tools_empty_array
    robot = build_non_network_robot
    robot.expects(:run).with("hello", mcp: :inherit, tools: :inherit).returns(@result)
    @runner.run(robot, "hello", tools: [])
  end

  def test_run_passes_tool_list_when_provided
    robot = build_non_network_robot
    robot.expects(:run).with("hello", mcp: :inherit, tools: ["tool_a", "tool_b"]).returns(@result)
    @runner.run(robot, "hello", tools: ["tool_a", "tool_b"])
  end

  def test_run_collects_streamed_chunks_into_content
    robot = build_non_network_robot
    chunk = mock('chunk')
    chunk.stubs(:respond_to?).with(:content).returns(true)
    chunk.stubs(:content).returns("hello ")
    # Simulate robot.run yielding a chunk
    robot.stubs(:run).yields(chunk).returns(@result)
    _result, content, _elapsed = @runner.run(robot, "hi")
    assert_equal "hello ", content
  end

  def test_run_collects_chunk_using_to_s_when_no_content_method
    robot = build_non_network_robot
    chunk = mock('chunk')
    chunk.stubs(:respond_to?).with(:content).returns(false)
    chunk.stubs(:to_s).returns("raw text")
    robot.stubs(:run).yields(chunk).returns(@result)
    _result, content, _elapsed = @runner.run(robot, "hi")
    assert_equal "raw text", content
  end

  def test_run_skips_empty_chunks
    robot = build_non_network_robot
    chunk = mock('chunk')
    chunk.stubs(:respond_to?).with(:content).returns(true)
    chunk.stubs(:content).returns("")  # empty — should be skipped
    robot.stubs(:run).yields(chunk).returns(@result)
    _result, content, _elapsed = @runner.run(robot, "hi")
    assert_nil content  # empty chunk excluded, streamed stays empty → nil
  end

  def test_run_network_uses_message_form
    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.expects(:run).with(message: "hello").returns(@result)
    @runner.run(network, "hello")
  end

  private

  def build_non_network_robot
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    robot
  end
end
