# frozen_string_literal: true
# test/aia/mcp_discovery_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class MCPDiscoveryTest < Minitest::Test
  def setup
    @decisions = AIA::Decisions.new
    @rule_router = mock('rule_router')
    @rule_router.stubs(:decisions).returns(@decisions)
    @discovery = AIA::MCPDiscovery.new(@rule_router)
  end

  def teardown
    super
  end

  def test_discover_returns_all_servers_when_no_rule_activations
    config = create_config(
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' },
        { name: 'server_c' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 3, result.length
    assert_equal 'server_a', result[0][:name]
    assert_equal 'server_b', result[1][:name]
    assert_equal 'server_c', result[2][:name]
  end

  def test_discover_returns_empty_when_no_mcp_flag_set
    config = create_config(
      flags: OpenStruct.new(no_mcp: true),
      mcp_servers: [{ name: 'server_a' }]
    )

    result = @discovery.discover(config)

    assert_equal [], result
  end

  def test_discover_filters_by_mcp_use_when_set
    config = create_config(
      mcp_use: ['server_b'],
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' },
        { name: 'server_c' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 1, result.length
    assert_equal 'server_b', result[0][:name]
  end

  def test_discover_returns_rule_activated_servers_when_activations_exist
    @decisions.add(:mcp_activate, server: 'server_c', reason: 'code domain')

    config = create_config(
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' },
        { name: 'server_c' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 1, result.length
    assert_equal 'server_c', result[0][:name]
  end

  def test_discover_returns_empty_array_when_no_servers_configured
    config = create_config(mcp_servers: nil)

    result = @discovery.discover(config)

    assert_equal [], result
  end

  def test_discover_with_string_keyed_server_names
    config = create_config(
      mcp_use: ['server_a'],
      mcp_servers: [
        { "name" => 'server_a' },
        { "name" => 'server_b' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 1, result.length
    assert_equal 'server_a', result[0]["name"]
  end

  def test_discover_returns_multiple_rule_activated_servers
    @decisions.add(:mcp_activate, server: 'server_a', reason: 'code domain')
    @decisions.add(:mcp_activate, server: 'server_c', reason: 'data domain')

    config = create_config(
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' },
        { name: 'server_c' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 2, result.length
    names = result.map { |s| s[:name] }
    assert_includes names, 'server_a'
    assert_includes names, 'server_c'
  end

  def test_discover_accepts_optional_input_parameter
    config = create_config(
      mcp_servers: [{ name: 'server_a' }]
    )

    result = @discovery.discover(config, "some user input")

    assert_equal 1, result.length
  end

  private

  def create_config(overrides = {})
    defaults = {
      flags: OpenStruct.new(no_mcp: false),
      mcp_use: nil,
      mcp_servers: []
    }
    OpenStruct.new(defaults.merge(overrides))
  end
end
