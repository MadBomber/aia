# frozen_string_literal: true
# test/aia/content_extractor_memory_test.rb

require_relative '../test_helper'

class ContentExtractorMemoryTest < Minitest::Test
  include AIA::ContentExtractor

  def test_store_results_in_memory_writes_structured_data
    memory = mock('memory')
    memory.expects(:current_writer=).with("task_a")
    memory.expects(:set).with(:result_task_a, {
      content: "Hello from A",
      model: "model-a",
      duration: 1.5
    })

    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(true)
    network.stubs(:memory).returns(memory)

    robot_result = OpenStruct.new(
      reply: "Hello from A",
      robot_name: "model-a",
      duration: 1.5
    )

    flow_result = OpenStruct.new(
      context: { task_a: robot_result }
    )

    store_results_in_memory(flow_result, network)
  end

  def test_store_results_skips_run_params
    memory = mock('memory')
    memory.expects(:current_writer=).never
    memory.expects(:set).never

    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(true)
    network.stubs(:memory).returns(memory)

    flow_result = OpenStruct.new(
      context: { run_params: { message: "test" } }
    )

    store_results_in_memory(flow_result, network)
  end

  def test_store_results_skips_non_reply_results
    memory = mock('memory')
    memory.expects(:set).never

    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(true)
    network.stubs(:memory).returns(memory)

    flow_result = OpenStruct.new(
      context: { task_a: "plain string without reply method" }
    )

    store_results_in_memory(flow_result, network)
  end

  def test_store_results_noop_without_memory
    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(false)

    flow_result = OpenStruct.new(context: {})

    # Should not raise
    store_results_in_memory(flow_result, network)
  end

  def test_store_results_handles_multiple_robots
    memory = mock('memory')
    memory.expects(:current_writer=).with("alice").once
    memory.expects(:current_writer=).with("bob").once
    memory.expects(:set).with(:result_alice, anything).once
    memory.expects(:set).with(:result_bob, anything).once

    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(true)
    network.stubs(:memory).returns(memory)

    flow_result = OpenStruct.new(
      context: {
        alice: OpenStruct.new(reply: "A's answer", robot_name: "alice-bot", duration: 1.0),
        bob: OpenStruct.new(reply: "B's answer", robot_name: "bob-bot", duration: 2.0)
      }
    )

    store_results_in_memory(flow_result, network)
  end
end
