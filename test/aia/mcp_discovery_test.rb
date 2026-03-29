# frozen_string_literal: true
# test/aia/mcp_discovery_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class MCPDiscoveryTest < Minitest::Test
  def setup
    @discovery = AIA::MCPDiscovery.new
  end

  def teardown
    super
  end

  def test_discover_returns_all_servers_when_no_mcp_use_set
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

  # ---------------------------------------------------------------------------
  # mcp_use: [] must NOT filter (empty array is truthy in Ruby)
  # ---------------------------------------------------------------------------

  def test_discover_treats_empty_mcp_use_as_unset
    config = create_config(
      mcp_use: [],   # empty array — should NOT restrict servers
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 2, result.length,
      "Empty mcp_use should fall through to all-servers, not filter to zero"
  end

  # ---------------------------------------------------------------------------
  # mcp_skip filtering
  # ---------------------------------------------------------------------------

  def test_discover_skips_servers_in_mcp_skip_list
    config = create_config(
      mcp_skip: ['server_b'],
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' },
        { name: 'server_c' }
      ]
    )

    result = @discovery.discover(config)

    names = result.map { |s| s[:name] }
    assert_includes names, 'server_a'
    refute_includes names, 'server_b'
    assert_includes names, 'server_c'
  end

  def test_discover_skip_with_empty_skip_list_returns_all
    config = create_config(
      mcp_skip: [],
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 2, result.length
  end

  private

  def create_config(overrides = {})
    defaults = {
      flags: OpenStruct.new(no_mcp: false),
      mcp_use: nil,
      mcp_skip: nil,
      mcp_servers: []
    }
    OpenStruct.new(defaults.merge(overrides))
  end
end
