# frozen_string_literal: true
# test/aia/network_memory_manager_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/network_memory_manager'

class NetworkMemoryManagerTest < Minitest::Test
  def test_initialize_memory_returns_network_without_memory
    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(false)
    config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4')],
      flags: OpenStruct.new(consensus: false)
    )

    result = AIA::NetworkMemoryManager.initialize_memory(network, config)
    assert_equal network, result
  end

  def test_initialize_memory_populates_session_data
    data   = OpenStruct.new
    memory = mock('memory')
    memory.stubs(:data).returns(data)

    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(true)
    network.stubs(:memory).returns(memory)

    config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4'), OpenStruct.new(name: 'claude')],
      flags: OpenStruct.new(consensus: true)
    )

    AIA::NetworkMemoryManager.initialize_memory(network, config)

    assert_equal 2, data.model_count
    assert_equal ['gpt-4', 'claude'], data.model_names
    assert_equal :consensus, data.mode
    assert_equal 0, data.turn_count
  end

  def test_setup_subscriptions_returns_when_no_memory
    network = mock('network')
    network.stubs(:respond_to?).with(:memory).returns(false)
    config = OpenStruct.new(flags: OpenStruct.new(debug: false))

    AIA::NetworkMemoryManager.setup_subscriptions(network, config) # passes if no exception raised
  end
end
