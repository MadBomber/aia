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
    @original_stderr = $stderr
    $stderr = StringIO.new # keep MCP failure warnings out of test output

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
    $stderr = @original_stderr
    AIA.mcp_manager = nil
    super
  end

  # Stands in for a RubyLLM::MCP server built by RobotLab::MCP.build.
  FakeServer = Struct.new(:name, :tool_list, :error) do
    def tools
      raise error if error

      tool_list
    end

    def close; end
  end

  def stub_server(name, tools: [], error: nil)
    RobotLab::MCP.stubs(:build).with { it[:name] == name }.returns(FakeServer.new(name, tools, error))
  end

  def connect(servers)
    @config.mcp_servers = servers
    AIA::MCPConnectionManager.start(@config)
  end

  def mcp_log_messages
    AIA::LoggerManager.test_entries(:mcp).map(&:message)
  end

  # =========================================================================
  # Requirement: connected_mcp_servers is set BEFORE banner is displayed
  # =========================================================================

  def test_mcp_connection_sets_connected_servers
    stub_server('serverA')
    stub_server('serverB', error: RubyLLM::Error.new('spawn failed'))

    connect([{ name: 'serverA', command: 'echo' }, { name: 'serverB', command: 'echo' }])

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
    mock_client.stubs(:crew).returns([mock_client])
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
    mock_client.stubs(:crew).returns([mock_client])
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
    @config.connected_mcp_servers = %w[serverA serverB serverC]
    @config.failed_mcp_servers = []

    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_client = mock('client')
    mock_client.stubs(:model).returns(mock_model)
    mock_client.stubs(:name).returns('TestBot')
    mock_client.stubs(:crew).returns([mock_client])
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
    stub_server('serverA')
    connect([{ name: 'serverA', command: 'echo' }])

    assert mcp_log_messages.any? { |m| m.include?('MCP initialization') && m.include?('connecting') },
           "Expected MCP initialization log. Got: #{mcp_log_messages.inspect}"
  end

  def test_mcp_connection_logs_connected_servers
    stub_server('serverA', tools: [Struct.new(:name).new('tool1')])
    connect([{ name: 'serverA', command: 'echo' }])

    assert mcp_log_messages.any? { |m| m.include?("'serverA' connected (1 tools)") },
           "Expected connected server log. Got: #{mcp_log_messages.inspect}"
  end

  def test_mcp_connection_logs_completion
    stub_server('serverA')
    connect([{ name: 'serverA', command: 'echo' }])

    assert mcp_log_messages.any? { |m| m.include?('MCP initialization complete') },
           "Expected completion log. Got: #{mcp_log_messages.inspect}"
  end

  def test_mcp_connection_logs_error_on_exception
    RobotLab::MCP.stubs(:build).raises(StandardError.new("connection timeout"))
    connect([{ name: 'serverX', command: 'bad' }])

    assert mcp_log_messages.any? { |m| m.include?("'serverX' error") && m.include?('connection timeout') },
           "Expected error log. Got: #{mcp_log_messages.inspect}"
  end

  # =========================================================================
  # Requirement: connected_mcp_servers is set even on exception
  # =========================================================================

  def test_connected_mcp_servers_set_even_when_all_servers_fail
    RobotLab::MCP.stubs(:build).raises(StandardError.new("total failure"))
    connect([{ name: 'serverA', command: 'bad' }])

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
    assert_equal %w[serverA serverB serverC], names
  end

  # =========================================================================
  # No servers selected → nothing connected, config left untouched
  # =========================================================================

  def test_start_skips_when_no_servers_configured
    RobotLab::MCP.expects(:build).never
    connect([])

    assert_nil @config.connected_mcp_servers
  end

  def test_start_skips_when_no_mcp_flag_set
    @config.flags.no_mcp = true
    RobotLab::MCP.expects(:build).never
    connect([{ name: 'serverA', command: 'echo' }])

    assert_nil @config.connected_mcp_servers
  end
end
