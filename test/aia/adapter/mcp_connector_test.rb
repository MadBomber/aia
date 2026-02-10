# frozen_string_literal: true

require_relative '../../test_helper'

class McpConnectorTest < Minitest::Test
  def setup
    @connector = AIA::Adapter::McpConnector.new
    @logger = mock('logger')
    @logger.stubs(:debug)
    @logger.stubs(:info)
    @logger.stubs(:warn)
    @logger.stubs(:error)
    @connector.instance_variable_set(:@logger, @logger)
  end

  def teardown
    super
  end

  def test_class_exists
    assert_kind_of Class, AIA::Adapter::McpConnector
  end

  def test_mcp_default_timeout_constant
    assert_equal 8_000, AIA::Adapter::McpConnector::MCP_DEFAULT_TIMEOUT
  end

  # --- support_mcp ---

  def test_support_mcp_skips_when_no_mcp_flag
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(no_mcp: true)
    ))

    tools = []
    @connector.support_mcp(tools)

    assert_empty tools
  end

  def test_support_mcp_calls_establish_connection
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(no_mcp: false)
    ))

    AIA::LoggerManager.stubs(:configure_mcp_logger)

    mock_tools = [mock('tool')]
    RubyLLM::MCP.expects(:establish_connection).once
    RubyLLM::MCP.stubs(:tools).returns(mock_tools)

    tools = []
    @connector.support_mcp(tools)

    assert_equal 1, tools.size
  end

  def test_support_mcp_handles_errors_gracefully
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(no_mcp: false)
    ))

    AIA::LoggerManager.stubs(:configure_mcp_logger)
    RubyLLM::MCP.stubs(:establish_connection).raises(StandardError, 'connection failed')

    # The mock logger should receive the error call
    @logger.expects(:error).with('Failed to connect MCP clients', has_entries(error_message: 'connection failed'))
    @connector.stubs(:warn)  # suppress warn output

    tools = []
    @connector.support_mcp(tools)

    assert_empty tools
  end

  # --- support_mcp_with_simple_flow ---

  def test_simple_flow_skips_when_no_mcp_flag
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(no_mcp: true)
    ))

    tools = []
    @connector.support_mcp_with_simple_flow(tools)
    assert_empty tools
  end

  def test_simple_flow_skips_when_no_servers
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(no_mcp: false),
      mcp_servers: nil
    ))

    tools = []
    @connector.support_mcp_with_simple_flow(tools)
    assert_empty tools
  end

  def test_simple_flow_skips_when_servers_empty
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(no_mcp: false),
      mcp_servers: []
    ))

    tools = []
    @connector.support_mcp_with_simple_flow(tools)
    assert_empty tools
  end

  # --- filter_mcp_servers ---

  def test_filter_mcp_servers_with_use_list
    AIA.stubs(:config).returns(OpenStruct.new(
      mcp_use: ['github'],
      mcp_skip: []
    ))

    servers = [
      { name: 'github', command: 'gh' },
      { name: 'filesystem', command: 'fs' }
    ]

    result = @connector.filter_mcp_servers(servers)
    assert_equal 1, result.size
    assert_equal 'github', result.first[:name]
  end

  def test_filter_mcp_servers_with_skip_list
    AIA.stubs(:config).returns(OpenStruct.new(
      mcp_use: [],
      mcp_skip: ['filesystem']
    ))

    servers = [
      { name: 'github', command: 'gh' },
      { name: 'filesystem', command: 'fs' }
    ]

    result = @connector.filter_mcp_servers(servers)
    assert_equal 1, result.size
    assert_equal 'github', result.first[:name]
  end

  def test_filter_use_takes_precedence_over_skip
    AIA.stubs(:config).returns(OpenStruct.new(
      mcp_use: ['github'],
      mcp_skip: ['github']
    ))

    servers = [
      { name: 'github', command: 'gh' },
      { name: 'filesystem', command: 'fs' }
    ]

    result = @connector.filter_mcp_servers(servers)
    assert_equal 1, result.size
    assert_equal 'github', result.first[:name]
  end

  def test_filter_returns_all_when_no_filters
    AIA.stubs(:config).returns(OpenStruct.new(
      mcp_use: [],
      mcp_skip: []
    ))

    servers = [
      { name: 'a', command: 'a' },
      { name: 'b', command: 'b' }
    ]

    result = @connector.filter_mcp_servers(servers)
    assert_equal 2, result.size
  end

  def test_filter_handles_string_keys
    AIA.stubs(:config).returns(OpenStruct.new(
      mcp_use: ['github'],
      mcp_skip: []
    ))

    servers = [
      { 'name' => 'github', 'command' => 'gh' },
      { 'name' => 'filesystem', 'command' => 'fs' }
    ]

    result = @connector.filter_mcp_servers(servers)
    assert_equal 1, result.size
    assert_equal 'github', result.first['name']
  end

  # --- determine_mcp_connection_error ---

  def test_connection_error_when_not_alive
    client = mock('client')
    client.stubs(:alive?).returns(false)

    result = @connector.send(:determine_mcp_connection_error, client, nil)
    assert_equal "Connection failed", result
  end

  def test_connection_error_when_caps_nil
    client = mock('client')
    client.stubs(:alive?).returns(true)

    result = @connector.send(:determine_mcp_connection_error, client, nil)
    assert_equal "Connection timed out (no response)", result
  end

  def test_connection_error_when_caps_empty_hash
    client = mock('client')
    client.stubs(:alive?).returns(true)

    result = @connector.send(:determine_mcp_connection_error, client, {})
    assert_equal "Connection timed out (empty capabilities)", result
  end

  def test_connection_error_other
    client = mock('client')
    client.stubs(:alive?).returns(true)

    result = @connector.send(:determine_mcp_connection_error, client, "something")
    assert_equal "Connection timed out (no capabilities received)", result
  end

  # --- report_mcp_connection_results ---

  def test_report_connected_servers
    AIA.stubs(:config).returns(OpenStruct.new(
      connected_mcp_servers: ['github'],
      failed_mcp_servers: []
    ))

    output = capture_io do
      @connector.send(:report_mcp_connection_results, 5)
    end

    assert_match(/Connected to github.*5 tools/, output[1])
  end

  def test_report_failed_servers
    AIA.stubs(:config).returns(OpenStruct.new(
      connected_mcp_servers: [],
      failed_mcp_servers: [{ name: 'bad-server', error: 'timed out' }]
    ))

    output = capture_io do
      @connector.send(:report_mcp_connection_results, 0)
    end

    assert_match(/bad-server.*timed out/, output[1])
    assert_match(/No servers connected successfully/, output[1])
  end

  def test_report_mixed_results
    AIA.stubs(:config).returns(OpenStruct.new(
      connected_mcp_servers: ['good-server'],
      failed_mcp_servers: [{ name: 'bad-server', error: 'failed' }]
    ))

    output = capture_io do
      @connector.send(:report_mcp_connection_results, 3)
    end

    assert_match(/Connected to good-server/, output[1])
    assert_match(/bad-server.*failed/, output[1])
  end
end
