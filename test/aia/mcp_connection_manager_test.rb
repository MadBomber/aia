# frozen_string_literal: true

# test/aia/mcp_connection_manager_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class MCPConnectionManagerTest < Minitest::Test
  # Stands in for a RubyLLM::MCP server: #tools connects (or raises), #close stops it.
  class FakeServer
    attr_reader :name, :closed

    def initialize(name, tools: [], error: nil)
      @name   = name
      @tools  = tools
      @error  = error
      @closed = false
    end

    def tools
      raise @error if @error

      @tools
    end

    def close
      @closed = true
    end
  end

  FakeTool = Struct.new(:name)

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
    stub_spinners
    $stderr.stubs(:tty?).returns(true) # failure warnings off; tests that check them use capture_io
  end

  def stub_spinners
    spinner = stub('spinner', auto_spin: nil, success: nil, error: nil)
    multi   = stub('multi')
    multi.stubs(:register).returns(spinner)
    TTY::Spinner::Multi.stubs(:new).returns(multi)
  end

  # RobotLab::MCP.build returns the FakeServer whose name matches the config.
  def stub_build(*fakes)
    fakes.each { |fake| RobotLab::MCP.stubs(:build).with { it[:name] == fake.name }.returns(fake) }
  end

  def config_for(name, **extra)
    { name: name, command: 'true', **extra }
  end

  # Initial state
  def test_initial_state_is_not_connected
    refute @manager.connected?
  end

  def test_initial_servers_is_empty
    assert_empty @manager.servers
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

  # connect_all — building and connecting servers
  def test_connect_all_records_connected_servers_and_tools
    fs = FakeServer.new('fs', tools: [FakeTool.new('read_file'), FakeTool.new('list_directory')])
    stub_build(fs)

    @manager.connect_all([config_for('fs')])

    assert @manager.connected?
    assert_equal [fs], @manager.servers
    assert_equal ['fs'], @manager.connected_server_names
    assert_equal %w[read_file list_directory], @manager.connected_tools.map(&:name)
    assert @manager.any_tools?
  end

  def test_connect_all_builds_from_normalized_config
    fs = FakeServer.new('fs')
    RobotLab::MCP.expects(:build).with { it[:transport] == { command: 'true', type: 'stdio' } }.returns(fs)

    @manager.connect_all([config_for('fs')])

    assert_equal ['fs'], @manager.connected_server_names
  end

  def test_connect_all_records_server_that_raises_as_failed
    dead = FakeServer.new('dead', error: RubyLLM::Error.new('spawn failed'))
    stub_build(dead)

    @manager.connect_all([config_for('dead')])

    assert_empty @manager.servers
    assert_equal ['dead'], @manager.failed_server_names
    assert_match(/spawn failed/, @manager.failed_servers.first[:error])
    assert dead.closed, 'a server that failed to connect is closed'
  end

  def test_connect_all_warns_about_failure_when_stderr_is_not_a_tty
    stub_build(FakeServer.new('dead', error: RubyLLM::Error.new('spawn failed')))

    _, err = capture_io { @manager.connect_all([config_for('dead')]) }

    assert_match(/MCP server 'dead' failed to connect: spawn failed/, err)
  end

  def test_connect_all_leaves_failure_to_the_spinner_when_stderr_is_a_tty
    stub_build(FakeServer.new('dead', error: RubyLLM::Error.new('spawn failed')))

    _, err = capture_io do
      $stderr.define_singleton_method(:tty?) { true }
      @manager.connect_all([config_for('dead')])
    end

    assert_empty err
  end

  def test_connect_all_records_unbuildable_config_as_failed
    RobotLab::MCP.stubs(:build).raises(RobotLab::MCPError, "uses transport 'sse'")

    @manager.connect_all([config_for('old', type: 'sse')])

    assert_equal ['old'], @manager.failed_server_names
    assert_match(/sse/, @manager.failed_servers.first[:error])
  end

  def test_connect_all_records_per_server_timeout_as_failed
    stub_build(FakeServer.new('slow'))
    Timeout.stubs(:timeout).with(30).raises(Timeout::Error)
    Timeout.stubs(:timeout).with(120).yields

    @manager.connect_all([config_for('slow')])

    assert_equal [{ name: 'slow', error: 'timed out after 30s' }], @manager.failed_servers
  end

  def test_connect_all_rejects_server_whose_tool_names_clash
    first  = FakeServer.new('first',  tools: [FakeTool.new('search')])
    second = FakeServer.new('second', tools: [FakeTool.new('search'), FakeTool.new('other')])
    stub_build(first, second)
    # Connect sequentially (no threads) so 'first' wins deterministically.
    def @manager.launch_server_threads(configs, multi)
      configs.each { |cfg| connect_one(cfg, cfg[:name], multi.register(cfg[:name])) }
      []
    end

    @manager.connect_all([config_for('first'), config_for('second')])

    assert_equal ['first'], @manager.connected_server_names
    assert_equal ['second'], @manager.failed_server_names
    assert_match(/'search' is also offered by 'first'.*prefix:/, @manager.failed_servers.first[:error])
    assert second.closed
  end

  def test_global_timeout_marks_unsettled_servers_failed
    @manager.instance_variable_set(:@servers, { 'ok' => FakeServer.new('ok') })

    @manager.send(:handle_global_timeout, [config_for('ok'), config_for('hung')], 120)

    assert_equal [{ name: 'hung', error: 'global connection timeout (120s)' }], @manager.failed_servers
    assert @manager.connected?
  end

  # Queries
  def test_servers_for_returns_connected_servers_by_name_in_requested_order
    a = FakeServer.new('a')
    b = FakeServer.new('b')
    @manager.instance_variable_set(:@servers, { 'a' => a, 'b' => b })

    assert_equal [b, a], @manager.servers_for([{ name: 'b' }, { 'name' => 'a' }])
    assert_equal [a], @manager.servers_for([{ name: 'a' }, { name: 'missing' }])
  end

  def test_server_returns_connected_server_or_nil
    a = FakeServer.new('a')
    @manager.instance_variable_set(:@servers, { 'a' => a })

    assert_same a, @manager.server('a')
    assert_nil @manager.server('nonexistent')
  end

  def test_tools_by_server_groups_tools_under_server_name
    tool = FakeTool.new('t')
    @manager.instance_variable_set(:@server_tools, { 'a' => [tool], 'b' => [] })

    assert_equal({ 'a' => [tool], 'b' => [] }, @manager.tools_by_server)
  end

  # update_config
  def test_update_config_sets_empty_results
    AIA.config.expects(:connected_mcp_servers=).with([]).once
    AIA.config.expects(:mcp_server_tool_counts=).with({}).once
    AIA.config.expects(:failed_mcp_servers=).with([]).once
    @manager.update_config
  end

  def test_update_config_publishes_names_counts_and_failures
    @manager.instance_variable_set(:@servers, { 'a' => FakeServer.new('a') })
    @manager.instance_variable_set(:@server_tools, { 'a' => [FakeTool.new('x'), FakeTool.new('y')] })
    @manager.instance_variable_set(:@failed_servers, [{ name: 'b', error: 'boom' }])

    AIA.config.expects(:connected_mcp_servers=).with(['a'])
    AIA.config.expects(:mcp_server_tool_counts=).with({ 'a' => 2 })
    AIA.config.expects(:failed_mcp_servers=).with([{ name: 'b', error: 'boom' }])
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

  # server_timeout (private method — test via send)
  def test_server_timeout_nil_config_returns_default
    result = @manager.send(:server_timeout, {})
    assert_equal AIA::MCPConnectionManager::DEFAULT_TIMEOUT, result
  end

  def test_server_timeout_small_seconds_value
    result = @manager.send(:server_timeout, { timeout: 15 })
    assert_equal 15.0, result
  end

  def test_server_timeout_reads_string_keys
    result = @manager.send(:server_timeout, { 'timeout' => 15 })
    assert_equal 15.0, result
  end

  def test_server_timeout_honors_value_above_default
    # A configured timeout larger than DEFAULT_TIMEOUT must be HONORED, not
    # clamped. Clamping silently dropped slow-starting servers (npx/uvx cold
    # starts) so their tools never reached the robot or the tool filter.
    result = @manager.send(:server_timeout, { timeout: 999 })
    assert_equal 999.0, result
  end

  def test_server_timeout_milliseconds_converted_to_seconds
    # 360000ms → 360.0s (6 min) — honored in full, not capped at DEFAULT_TIMEOUT.
    result = @manager.send(:server_timeout, { timeout: 360_000 })
    assert_equal 360.0, result
  end

  def test_server_timeout_non_hash_config_returns_default
    result = @manager.send(:server_timeout, "not_a_hash")
    assert_equal AIA::MCPConnectionManager::DEFAULT_TIMEOUT, result
  end

  # ===================================================================
  # close_all
  # ===================================================================

  def test_close_all_closes_each_server
    a = FakeServer.new('a')
    b = FakeServer.new('b')
    @manager.instance_variable_set(:@servers, { 'a' => a, 'b' => b })
    @manager.instance_variable_set(:@connected, true)

    @manager.close_all

    assert a.closed
    assert b.closed
  end

  def test_close_all_sets_connected_to_false_and_clears_state
    @manager.instance_variable_set(:@connected, true)
    @manager.instance_variable_set(:@servers, { 'a' => FakeServer.new('a') })
    @manager.instance_variable_set(:@server_tools, { 'a' => [FakeTool.new('t')] })

    @manager.close_all

    refute @manager.connected?
    assert_empty @manager.servers
    assert_empty @manager.connected_tools
  end

  def test_close_all_rescues_server_close_errors
    bad = mock('bad_server')
    bad.stubs(:close).raises(RuntimeError, "connection already closed")
    @manager.instance_variable_set(:@servers, { "bad" => bad })

    @manager.close_all # must not raise

    assert_empty @manager.servers
  end

  # ===================================================================
  # .start
  # ===================================================================

  def start_config(**overrides)
    OpenStruct.new(
      flags:       OpenStruct.new(no_mcp: false),
      mcp_servers: [config_for('fs')],
      mcp_use:     [],
      mcp_skip:    [],
      **overrides
    )
  end

  def test_start_connects_discovered_servers_and_publishes_manager
    cfg = start_config
    AIA.stubs(:config).returns(cfg)
    stub_build(FakeServer.new('fs', tools: [FakeTool.new('t')]))
    AIA.expects(:mcp_manager=).with { it.is_a?(AIA::MCPConnectionManager) }

    assert_kind_of AIA::MCPConnectionManager, AIA::MCPConnectionManager.start(cfg)
    assert_equal ['fs'], cfg.connected_mcp_servers
    assert_equal({ 'fs' => 1 }, cfg.mcp_server_tool_counts)
  end

  def test_start_with_no_mcp_connects_nothing
    cfg = start_config(flags: OpenStruct.new(no_mcp: true))
    RobotLab::MCP.expects(:build).never
    AIA.expects(:mcp_manager=).with { !it.connected? }

    AIA::MCPConnectionManager.start(cfg)
  end

  def test_start_applies_mcp_skip
    cfg = start_config(mcp_skip: ['fs'])
    RobotLab::MCP.expects(:build).never
    AIA.stubs(:mcp_manager=)

    AIA::MCPConnectionManager.start(cfg)
  end

  def test_warn_unknown_mcp_use_names_lists_missing_and_available
    cfg = start_config(mcp_use: %w[fs typo])

    _, err = capture_io do
      AIA::MCPConnectionManager.warn_unknown_mcp_use_names(cfg, [config_for('fs')])
    end

    assert_match(/not found in config: typo/, err)
    assert_match(/Available servers: fs/, err)
  end

  def test_warn_unknown_mcp_use_names_silent_when_all_found
    cfg = start_config(mcp_use: %w[fs])

    _, err = capture_io do
      AIA::MCPConnectionManager.warn_unknown_mcp_use_names(cfg, [config_for('fs')])
    end

    assert_empty err
  end

  # ===================================================================
  # global_connection_timeout
  # ===================================================================

  def test_global_connection_timeout_returns_default_when_no_config
    AIA.stubs(:config).returns(nil)
    result = @manager.send(:global_connection_timeout)
    assert_equal 120, result
  end

  def test_global_connection_timeout_reads_from_config
    AIA.stubs(:config).returns(
      OpenStruct.new(
        concurrency: OpenStruct.new(mcp_timeout: 60),
        connected_mcp_servers: nil,
        mcp_server_tool_counts: nil,
        failed_mcp_servers: nil
      )
    )
    result = @manager.send(:global_connection_timeout)
    assert_equal 60, result
  end
end
