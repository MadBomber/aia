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

  # ---------------------------------------------------------------------------
  # 7.1 — mcp_use: [] must NOT filter (empty array is truthy in Ruby)
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
  # 7.1 — mcp_skip filtering
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

  def test_discover_skip_applied_after_kbs_activation
    @decisions.add(:mcp_activate, server: 'server_a', reason: 'code domain')
    @decisions.add(:mcp_activate, server: 'server_b', reason: 'data domain')

    config = create_config(
      mcp_skip: ['server_b'],
      mcp_servers: [
        { name: 'server_a' },
        { name: 'server_b' },
        { name: 'server_c' }
      ]
    )

    result = @discovery.discover(config)

    assert_equal 1, result.length
    assert_equal 'server_a', result[0][:name],
      "KBS activated server_a and server_b, but server_b is in skip list"
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

  # ---------------------------------------------------------------------------
  # 7.1 — StartupCoordinator wires MCPDiscovery
  # ---------------------------------------------------------------------------

  def test_startup_coordinator_uses_discovery_when_robot_has_no_mcp_config
    robot = mock('robot')
    robot.stubs(:respond_to?).with(:mcp_config).returns(false)
    robot.stubs(:respond_to?).with(:robots).returns(false)
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)

    config = OpenStruct.new(
      flags: OpenStruct.new(no_mcp: false, track_pipeline: false),
      mcp_servers: [
        { name: 'server_a', command: 'cmd' },
        { name: 'server_b', command: 'cmd' }
      ],
      mcp_use: nil,
      mcp_skip: ['server_b'],
      mcp_use: nil,
      loaded_tools: []
    )

    AIA.stubs(:config).returns(config)
    AIA.stubs(:turn_state).returns(OpenStruct.new(active_mcp_servers: []))

    mcp_mgr = mock('mcp_manager')
    mcp_mgr.stubs(:connect_all)
    mcp_mgr.stubs(:absorb_ruby_llm_mcp_clients)
    mcp_mgr.stubs(:connected?).returns(false)
    AIA::MCPConnectionManager.stubs(:new).returns(mcp_mgr)

    AIA::ToolFilterRegistry.stubs(:build_from_config).returns({})
    AIA::TaskCoordinator.stubs(:new).raises(StandardError)

    coordinator = AIA::StartupCoordinator.new(
      robot: robot,
      rule_router: @rule_router,
      ui_presenter: mock('ui')
    )

    connected_servers = nil
    mcp_mgr.stubs(:connect_all).with { |servers| connected_servers = servers; true }

    coordinator.run(config)

    refute_nil connected_servers
    names = connected_servers.map { |s| s[:name] || (s[:transport] && s[:name]) }.compact
    refute_includes names, 'server_b', "server_b should be skipped by MCPDiscovery"
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
