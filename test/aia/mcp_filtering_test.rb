# frozen_string_literal: true

require_relative '../test_helper'

class McpFilteringTest < Minitest::Test
  def setup
    @servers = [
      { name: 'github', command: 'github-mcp-server', args: ['stdio'] },
      { name: 'filesystem', command: 'npx', args: ['-y', '@modelcontextprotocol/server-filesystem'] },
      { name: 'playwright', command: 'playwright-mcp-server', args: [] }
    ]
  end

  def test_filter_mcp_servers_with_use_list
    connector = build_connector_with(mcp_use: ['github'], mcp_skip: [])
    result = connector.filter_mcp_servers(@servers)

    assert_equal 1, result.size
    assert_equal 'github', result.first[:name]
  end

  def test_filter_mcp_servers_with_skip_list
    connector = build_connector_with(mcp_use: [], mcp_skip: ['playwright'])
    result = connector.filter_mcp_servers(@servers)

    assert_equal 2, result.size
    names = result.map { |s| s[:name] }
    assert_includes names, 'github'
    assert_includes names, 'filesystem'
    refute_includes names, 'playwright'
  end

  def test_mcp_use_takes_precedence_over_skip
    connector = build_connector_with(mcp_use: ['github'], mcp_skip: ['github'])
    result = connector.filter_mcp_servers(@servers)

    assert_equal 1, result.size
    assert_equal 'github', result.first[:name]
  end

  def test_filter_with_empty_lists
    connector = build_connector_with(mcp_use: [], mcp_skip: [])
    result = connector.filter_mcp_servers(@servers)

    assert_equal 3, result.size
  end

  def test_filter_with_string_keys
    servers_with_string_keys = [
      { 'name' => 'github', 'command' => 'github-mcp-server' },
      { 'name' => 'filesystem', 'command' => 'npx' }
    ]

    connector = build_connector_with(mcp_use: ['github'], mcp_skip: [])
    result = connector.filter_mcp_servers(servers_with_string_keys)

    assert_equal 1, result.size
    assert_equal 'github', result.first['name']
  end

  def test_filter_with_multiple_use_names
    connector = build_connector_with(mcp_use: ['github', 'filesystem'], mcp_skip: [])
    result = connector.filter_mcp_servers(@servers)

    assert_equal 2, result.size
    names = result.map { |s| s[:name] }
    assert_includes names, 'github'
    assert_includes names, 'filesystem'
  end

  def test_filter_with_nonexistent_use_name
    connector = build_connector_with(mcp_use: ['nonexistent'], mcp_skip: [])
    result = connector.filter_mcp_servers(@servers)

    assert_empty result
  end

  private

  def build_connector_with(mcp_use:, mcp_skip:)
    config = mock('config')
    config.stubs(:mcp_use).returns(mcp_use)
    config.stubs(:mcp_skip).returns(mcp_skip)
    AIA.stubs(:config).returns(config)

    connector = AIA::Adapter::McpConnector.new
    logger = mock('logger')
    logger.stubs(:info)
    logger.stubs(:debug)
    connector.instance_variable_set(:@logger, logger)

    connector
  end
end
