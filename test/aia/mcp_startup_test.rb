require_relative '../test_helper'
require 'ostruct'
require 'stringio'
require_relative '../../lib/aia'

# Tests the requirement:
#   All MCP servers defined in the config file MUST be connected as the first
#   thing done by the AIA program in chat mode. This MUST occur and be
#   completely logged BEFORE the chat mode banner is shown. In that banner
#   only successfully connected MCP server names are to be shown.
class MCPStartupTest < Minitest::Test
  def setup
    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output

    AIA::LoggerManager.clear_test_logs!

    @config = OpenStruct.new(
      prompt_id: nil,
      context_files: [],
      stdin_content: nil,
      pipeline: [],
      mcp_servers: [
        { name: 'serverA', command: 'echo', args: ['hello'] },
        { name: 'serverB', command: 'echo', args: ['world'] },
        { name: 'serverC', command: 'echo', args: ['bye'] }
      ],
      mcp_use: [],
      mcp_skip: [],
      tool_names: '',
      loaded_tools: [],
      connected_mcp_servers: nil,
      failed_mcp_servers: nil,
      prompts: OpenStruct.new(
        dir: '/tmp/test_prompts', extname: '.md', roles_prefix: 'roles',
        roles_dir: '/tmp/test_prompts/roles', role: nil, system_prompt: 'You are helpful'
      ),
      output: OpenStruct.new(file: nil, append: false, markdown: true, history_file: nil),
      flags: OpenStruct.new(
        chat: true, fuzzy: false, debug: false, verbose: false,
        speak: false, tokens: false, no_mcp: false, track_pipeline: false
      ),
      llm: OpenStruct.new(
        temperature: 0.7, max_tokens: 2048, top_p: 1.0,
        frequency_penalty: 0.0, presence_penalty: 0.0
      ),
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini')],
      tools: OpenStruct.new(paths: [], allowed: nil, rejected: nil),
      audio: OpenStruct.new(voice: 'alloy', speak_command: 'afplay', speech_model: 'tts-1'),
      registry: OpenStruct.new(refresh: 7),
      paths: OpenStruct.new(aia_dir: '/tmp/aia_test'),
      rules: OpenStruct.new(dir: nil, enabled: false),
      logger: OpenStruct.new(
        aia: OpenStruct.new(file: 'STDOUT', level: 'debug', flush: true),
        llm: OpenStruct.new(file: 'STDOUT', level: 'debug', flush: true),
        mcp: OpenStruct.new(file: 'STDOUT', level: 'debug', flush: true)
      )
    )

    AIA.stubs(:config).returns(@config)
    AIA.stubs(:chat?).returns(true)
    AIA.stubs(:append?).returns(false)
    AIA.stubs(:verbose?).returns(false)
    AIA.stubs(:speak?).returns(false)
    AIA.stubs(:debug?).returns(false)
    TTY::Screen.stubs(:width).returns(100)
    AIA::Utility.stubs(:models_last_refresh).returns('2025-01-01 12:00')
  end

  def teardown
    $stdout = @original_stdout
    super
  end

  # Helper: create a StartupCoordinator with a given robot for connect_mcp_servers testing.
  # Stubs rule_router.decisions so MCPDiscovery can read mcp_activations.
  def build_coordinator(robot)
    rr = mock('rule_router')
    rr.stubs(:decisions).returns(AIA::Decisions.new)
    AIA::StartupCoordinator.new(robot: robot, rule_router: rr, ui_presenter: mock('ui_presenter'))
  end

  # Helper: create a mock robot with mcp_config that returns server configs
  def build_mock_robot(server_configs:)
    mock_robot = mock('robot')
    mock_robot.stubs(:respond_to?).with(:mcp_config).returns(true)
    mock_robot.stubs(:respond_to?).with(:robots).returns(false)
    mock_robot.stubs(:mcp_config).returns(server_configs)
    mock_robot.stubs(:inject_mcp!)
    mock_robot
  end

  # Helper: create a mock MCP client
  def build_mock_client(connected:, tools: [])
    client = mock('mcp_client')
    client.stubs(:connect)
    client.stubs(:connected?).returns(connected)
    client.stubs(:list_tools).returns(tools) if connected
    client
  end

  # =========================================================================
  # Requirement: connected_mcp_servers is set BEFORE banner is displayed
  # =========================================================================

  def test_mcp_connection_sets_connected_servers
    server_configs = [
      { name: 'serverA', transport: { type: 'stdio', command: 'echo' } },
      { name: 'serverB', transport: { type: 'stdio', command: 'echo' } }
    ]
    mock_robot = build_mock_robot(server_configs: server_configs)

    # serverA connects, serverB fails
    client_a = build_mock_client(connected: true, tools: [])
    client_b = build_mock_client(connected: false)

    RobotLab::MCP::Client.stubs(:new).with(server_configs[0]).returns(client_a)
    RobotLab::MCP::Client.stubs(:new).with(server_configs[1]).returns(client_b)

    # Mock server name for connected client
    server_obj = mock('server')
    server_obj.stubs(:name).returns('serverA')
    client_a.stubs(:server).returns(server_obj)

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    assert_equal ['serverA'], @config.connected_mcp_servers
    assert_equal 1, @config.failed_mcp_servers.size
    assert_equal 'serverB', @config.failed_mcp_servers.first[:name]
  end

  # =========================================================================
  # Requirement: banner shows only connected server names
  # v2 banner format:
  #   MCP: serverA | FAILED: serverB, serverC
  #   MCP: FAILED: serverA, serverB, serverC
  #   MCP: serverA, serverB, serverC
  # =========================================================================

  def test_banner_shows_mcp_counts_with_mixed_results
    @config.connected_mcp_servers = ['serverA']
    @config.failed_mcp_servers = [
      { name: 'serverB', error: 'connection failed' },
      { name: 'serverC', error: 'connection failed' }
    ]

    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_client = mock('client')
    mock_client.stubs(:model).returns(mock_model)
    mock_client.stubs(:name).returns('TestBot')
    AIA.stubs(:client).returns(mock_client)

    AIA::Utility.robot
    output = @captured_output.string

    # v2 banner shows connected names and FAILED names inline
    assert_includes output, 'serverA'
    assert_includes output, 'FAILED:'
    assert_includes output, 'serverB'
    assert_includes output, 'serverC'
  end

  def test_banner_shows_all_failed_counts
    @config.connected_mcp_servers = []
    @config.failed_mcp_servers = [
      { name: 'serverA', error: 'failed' },
      { name: 'serverB', error: 'failed' },
      { name: 'serverC', error: 'failed' }
    ]

    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_client = mock('client')
    mock_client.stubs(:model).returns(mock_model)
    mock_client.stubs(:name).returns('TestBot')
    AIA.stubs(:client).returns(mock_client)

    AIA::Utility.robot
    output = @captured_output.string

    # v2 banner: "MCP: FAILED: serverA, serverB, serverC"
    assert_includes output, 'FAILED:'
    assert_includes output, 'serverA'
    assert_includes output, 'serverB'
    assert_includes output, 'serverC'
  end

  def test_banner_shows_all_connected_counts
    @config.connected_mcp_servers = ['serverA', 'serverB', 'serverC']
    @config.failed_mcp_servers = []

    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_client = mock('client')
    mock_client.stubs(:model).returns(mock_model)
    mock_client.stubs(:name).returns('TestBot')
    AIA.stubs(:client).returns(mock_client)

    AIA::Utility.robot
    output = @captured_output.string

    # v2 banner: "MCP: serverA, serverB, serverC"
    assert_includes output, 'serverA'
    assert_includes output, 'serverB'
    assert_includes output, 'serverC'
    refute_includes output, 'FAILED'
  end

  # =========================================================================
  # Requirement: MCP connection is LOGGED
  # =========================================================================

  def test_mcp_connection_logs_initialization_start
    mock_robot = build_mock_robot(server_configs: [
      { name: 'serverA', transport: { type: 'stdio', command: 'echo' } }
    ])

    client = build_mock_client(connected: true, tools: [])
    server_obj = mock('server')
    server_obj.stubs(:name).returns('serverA')
    client.stubs(:server).returns(server_obj)
    RobotLab::MCP::Client.stubs(:new).returns(client)

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    entries = AIA::LoggerManager.test_entries(:mcp)
    messages = entries.map(&:message)

    assert messages.any? { |m| m.include?('MCP initialization') && m.include?('connecting') },
           "Expected MCP initialization log. Got: #{messages.inspect}"
  end

  def test_mcp_connection_logs_connected_servers
    mock_robot = build_mock_robot(server_configs: [
      { name: 'serverA', transport: { type: 'stdio', command: 'echo' } }
    ])

    client = build_mock_client(connected: true, tools: [{ name: 'tool1', description: 'desc', inputSchema: {} }])
    server_obj = mock('server')
    server_obj.stubs(:name).returns('serverA')
    client.stubs(:server).returns(server_obj)
    RobotLab::MCP::Client.stubs(:new).returns(client)
    RobotLab::Tool.stubs(:create).returns(mock('tool'))

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    entries = AIA::LoggerManager.test_entries(:mcp)
    messages = entries.map(&:message)

    assert messages.any? { |m| m.include?("'serverA' connected") },
           "Expected connected server log. Got: #{messages.inspect}"
  end

  def test_mcp_connection_logs_failed_servers
    mock_robot = build_mock_robot(server_configs: [
      { name: 'serverB', transport: { type: 'stdio', command: 'bad_cmd' } }
    ])

    client = build_mock_client(connected: false)
    RobotLab::MCP::Client.stubs(:new).returns(client)

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    entries = AIA::LoggerManager.test_entries(:mcp)
    messages = entries.map(&:message)

    assert messages.any? { |m| m.include?("'serverB' failed") },
           "Expected failed server log. Got: #{messages.inspect}"
  end

  def test_mcp_connection_logs_completion
    mock_robot = build_mock_robot(server_configs: [
      { name: 'serverA', transport: { type: 'stdio', command: 'echo' } }
    ])

    client = build_mock_client(connected: true, tools: [])
    server_obj = mock('server')
    server_obj.stubs(:name).returns('serverA')
    client.stubs(:server).returns(server_obj)
    RobotLab::MCP::Client.stubs(:new).returns(client)

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    entries = AIA::LoggerManager.test_entries(:mcp)
    messages = entries.map(&:message)

    assert messages.any? { |m| m.include?('MCP initialization complete') },
           "Expected completion log. Got: #{messages.inspect}"
  end

  def test_mcp_connection_logs_error_on_exception
    mock_robot = build_mock_robot(server_configs: [
      { name: 'serverX', transport: { type: 'stdio', command: 'bad' } }
    ])

    RobotLab::MCP::Client.stubs(:new).raises(StandardError.new("connection timeout"))

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    entries = AIA::LoggerManager.test_entries(:mcp)
    messages = entries.map(&:message)

    assert messages.any? { |m| m.include?("'serverX' error") && m.include?('connection timeout') },
           "Expected error log. Got: #{messages.inspect}"
  end

  # =========================================================================
  # Requirement: connected_mcp_servers is set even on exception
  # =========================================================================

  def test_connected_mcp_servers_set_even_when_all_servers_fail
    mock_robot = build_mock_robot(server_configs: [
      { name: 'serverA', transport: { type: 'stdio', command: 'bad' } }
    ])

    RobotLab::MCP::Client.stubs(:new).raises(StandardError.new("total failure"))

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    refute_nil @config.connected_mcp_servers
    assert_equal [], @config.connected_mcp_servers
    assert_equal 1, @config.failed_mcp_servers.size
  end

  # =========================================================================
  # Requirement: mcp_server_names returns ONLY connected servers
  # =========================================================================

  def test_mcp_server_names_returns_only_connected_when_set
    @config.connected_mcp_servers = ['serverA']
    assert_equal ['serverA'], AIA::Utility.mcp_server_names
  end

  def test_mcp_server_names_returns_empty_when_none_connected
    @config.connected_mcp_servers = []
    assert_equal [], AIA::Utility.mcp_server_names
  end

  def test_mcp_server_names_falls_back_before_connection_attempted
    @config.connected_mcp_servers = nil
    names = AIA::Utility.mcp_server_names
    assert_equal ['serverA', 'serverB', 'serverC'], names
  end

  # =========================================================================
  # connect_mcp_servers skips when robot has no MCP config
  # =========================================================================

  def test_connect_mcp_servers_skips_when_no_mcp_config
    mock_robot = mock('robot')
    mock_robot.stubs(:respond_to?).with(:mcp_config).returns(false)

    # Also clear AIA config servers so the fallback path finds nothing
    @config.mcp_servers = []
    @config.flags.no_mcp = false

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    assert_nil @config.connected_mcp_servers
  end

  def test_connect_mcp_servers_skips_when_mcp_config_empty
    mock_robot = mock('robot')
    mock_robot.stubs(:respond_to?).with(:mcp_config).returns(true)
    mock_robot.stubs(:mcp_config).returns([])

    build_coordinator(mock_robot).send(:connect_mcp_servers, @config)

    assert_nil @config.connected_mcp_servers
  end
end
