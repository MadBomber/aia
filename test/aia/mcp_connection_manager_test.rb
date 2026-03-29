# frozen_string_literal: true
# test/aia/mcp_connection_manager_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class MCPConnectionManagerTest < Minitest::Test
  def setup
    @manager = AIA::MCPConnectionManager.new
    AIA.stubs(:config).returns(
      OpenStruct.new(
        connected_mcp_servers:  nil,
        mcp_server_tool_counts: nil,
        failed_mcp_servers:     nil
      )
    )
    AIA.config.stubs(:connected_mcp_servers=)
    AIA.config.stubs(:mcp_server_tool_counts=)
    AIA.config.stubs(:failed_mcp_servers=)
  end

  def teardown
    super
  end

  # Initial state
  def test_initial_state_is_not_connected
    refute @manager.connected?
  end

  def test_initial_connected_clients_is_empty
    assert_equal({}, @manager.connected_clients)
  end

  def test_initial_connected_tools_is_empty
    assert_empty @manager.connected_tools
  end

  def test_initial_failed_servers_is_empty
    assert_empty @manager.failed_servers
  end

  # connect_all with empty/nil input
  def test_connect_all_empty_array_returns_self
    result = @manager.connect_all([])
    assert_same @manager, result
  end

  def test_connect_all_nil_returns_self
    result = @manager.connect_all(nil)
    assert_same @manager, result
  end

  def test_connect_all_empty_leaves_connected_false
    @manager.connect_all([])
    refute @manager.connected?
  end

  # server_timeout (private method — test via send)
  def test_server_timeout_nil_config_returns_default
    result = @manager.send(:server_timeout, {})
    assert_equal AIA::MCPConnectionManager::DEFAULT_TIMEOUT, result
  end

  def test_server_timeout_small_seconds_value
    result = @manager.send(:server_timeout, { timeout: 15 })
    assert_equal 15.0, result
  end

  def test_server_timeout_capped_at_default
    result = @manager.send(:server_timeout, { timeout: 999 })
    assert_equal AIA::MCPConnectionManager::DEFAULT_TIMEOUT, result
  end

  def test_server_timeout_milliseconds_converted_to_seconds
    # 5000ms → 5.0s, which is < DEFAULT_TIMEOUT
    result = @manager.send(:server_timeout, { timeout: 5000 })
    assert_equal 5.0, result
  end

  def test_server_timeout_non_hash_config_returns_default
    result = @manager.send(:server_timeout, "not_a_hash")
    assert_equal AIA::MCPConnectionManager::DEFAULT_TIMEOUT, result
  end

  # inject_into — single robot
  def test_inject_into_single_robot_calls_inject_mcp
    robot = mock('robot')
    robot.stubs(:respond_to?).with(:robots).returns(false)
    robot.expects(:inject_mcp!).with(clients: {}, tools: []).once

    @manager.inject_into(robot)
  end

  def test_inject_into_network_calls_inject_mcp_on_each_robot
    robot_a = mock('robot_a')
    robot_b = mock('robot_b')
    robot_a.expects(:inject_mcp!).with(clients: {}, tools: []).once
    robot_b.expects(:inject_mcp!).with(clients: {}, tools: []).once

    network = mock('network')
    network.stubs(:respond_to?).with(:robots).returns(true)
    network.stubs(:robots).returns({ a: robot_a, b: robot_b })

    @manager.inject_into(network)
  end

  # update_config
  def test_update_config_sets_connected_mcp_servers
    AIA.config.expects(:connected_mcp_servers=).with([]).once
    AIA.config.expects(:mcp_server_tool_counts=).with({}).once
    AIA.config.expects(:failed_mcp_servers=).with([]).once
    @manager.update_config
  end

  # helper methods
  def test_connected_server_names_initially_empty
    assert_empty @manager.connected_server_names
  end

  def test_failed_server_names_initially_empty
    assert_empty @manager.failed_server_names
  end

  def test_any_tools_false_when_no_tools
    refute @manager.any_tools?
  end

  def test_client_returns_nil_for_unknown_server
    assert_nil @manager.client("nonexistent")
  end

  # absorb_ruby_llm_mcp_clients — no RubyLLM::MCP defined
  def test_absorb_returns_self_when_ruby_llm_mcp_not_defined
    result = @manager.absorb_ruby_llm_mcp_clients
    assert_same @manager, result
  end

  # ===================================================================
  # close_all
  # ===================================================================

  def test_close_all_calls_close_on_each_client
    client_a = mock('client_a')
    client_b = mock('client_b')
    client_a.expects(:close).once
    client_b.expects(:close).once

    @manager.instance_variable_set(:@connected_clients, { "a" => client_a, "b" => client_b })
    @manager.instance_variable_set(:@connected, true)

    @manager.close_all
  end

  def test_close_all_sets_connected_to_false
    @manager.instance_variable_set(:@connected, true)
    @manager.instance_variable_set(:@connected_clients, {})

    @manager.close_all

    refute @manager.connected?
  end

  def test_close_all_clears_connected_clients
    client = mock('client')
    client.stubs(:close)
    @manager.instance_variable_set(:@connected_clients, { "a" => client })

    @manager.close_all

    assert_empty @manager.connected_clients
  end

  def test_close_all_rescues_client_close_errors
    bad_client = mock('bad_client')
    bad_client.stubs(:close).raises(RuntimeError, "connection already closed")
    @manager.instance_variable_set(:@connected_clients, { "bad" => bad_client })

    # close_all must not propagate the RuntimeError
    raised = false
    begin
      @manager.close_all
    rescue RuntimeError
      raised = true
    end
    refute raised, "close_all should not raise when a client#close raises"
  end
end
