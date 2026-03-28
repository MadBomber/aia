# frozen_string_literal: true
# test/aia/robot_factory_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class RobotFactoryTest < Minitest::Test
  def setup
    @config = create_test_config
    AIA.stubs(:config).returns(@config)
  end

  def teardown
    super
  end

  def test_mcp_server_configs_returns_empty_when_no_mcp
    @config.flags.no_mcp = true
    result = AIA::RobotFactory.send(:mcp_server_configs, @config)
    assert_equal [], result
  end

  def test_mcp_server_configs_returns_all_when_no_filters
    @config.flags.no_mcp = false
    @config.mcp_servers = [{ name: 'server1' }, { name: 'server2' }]

    result = AIA::RobotFactory.send(:mcp_server_configs, @config)
    assert_equal 2, result.length
  end

  def test_mcp_server_configs_applies_use_filter
    @config.flags.no_mcp = false
    @config.mcp_servers = [{ name: 'server1' }, { name: 'server2' }]
    @config.mcp_use = ['server1']

    result = AIA::RobotFactory.send(:mcp_server_configs, @config)
    assert_equal 1, result.length
    assert_equal 'server1', result.first[:name]
  end

  def test_mcp_server_configs_applies_skip_filter
    @config.flags.no_mcp = false
    @config.mcp_servers = [{ name: 'server1' }, { name: 'server2' }]
    @config.mcp_skip = ['server2']

    result = AIA::RobotFactory.send(:mcp_server_configs, @config)
    assert_equal 1, result.length
    assert_equal 'server1', result.first[:name]
  end

  def test_build_run_config_creates_config
    result = AIA::RobotFactory.send(:build_run_config, @config)
    assert_instance_of RobotLab::RunConfig, result
  end

  def test_build_streaming_callback_returns_nil_when_not_chat
    @config.flags.chat = false
    result = AIA::RobotFactory.send(:build_streaming_callback, @config)
    assert_nil result
  end

  def test_build_streaming_callback_returns_nil_when_chat
    # Streaming is disabled because it conflicts with the spinner in ChatLoop
    @config.flags.chat = true
    result = AIA::RobotFactory.send(:build_streaming_callback, @config)
    assert_nil result
  end

  # I4/I5: Tool caching — build() uses ToolLoader
  def test_build_skips_load_tools_when_cache_exists
    tool = mock('cached_tool')
    tool.stubs(:name).returns('CachedTool')
    AIA::ToolLoader.instance.instance_variable_set(:@tool_cache, [tool])

    # build() should assign cached tools to config without calling load_tools
    AIA::RobotFactory.stubs(:configure_robot_lab)
    AIA::ToolLoader.expects(:load_tools).never

    # Stub the actual robot building
    mock_robot = mock('robot')
    AIA::RobotFactory.stubs(:build_single_robot).returns(mock_robot)

    AIA::RobotFactory.build(@config)

    assert_equal [tool], @config.loaded_tools
    assert_equal 'CachedTool', @config.tool_names
  ensure
    AIA::ToolLoader.clear_cache!
  end

  # Forwarding wrappers
  def test_clear_tool_cache_delegates_to_tool_loader
    AIA::ToolLoader.instance.instance_variable_set(:@tool_cache, [:fake])
    AIA::RobotFactory.clear_tool_cache!
    assert_nil AIA::ToolLoader.cached_tools
  end

  def test_filtered_tools_delegates_to_tool_loader
    @config.loaded_tools = []
    result = AIA::RobotFactory.filtered_tools(@config)
    assert_equal [], result
  end

  def test_resolve_system_prompt_delegates_to_assembler
    @config.prompts.system_prompt = 'Hello'
    @config.prompts.role = nil
    model_spec = OpenStruct.new(name: 'gpt-4o', role: nil)
    result = AIA::RobotFactory.resolve_system_prompt(@config, model_spec)
    assert_equal 'Hello', result
  end

  def test_build_identity_prompt_delegates_to_assembler
    spec = OpenStruct.new(name: 'gpt-4o', provider: nil)
    roster = [{ name: 'Tobor', spec: spec }]
    result = AIA::RobotFactory.build_identity_prompt('Tobor', spec, roster)
    assert_match(/You are Tobor/, result)
  end

  private

  def create_test_config
    OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini')],
      pipeline: [],
      context_files: [],
      mcp_servers: [],
      mcp_use: [],
      mcp_skip: [],
      require_libs: [],
      loaded_tools: [],
      tool_names: '',
      prompts: OpenStruct.new(
        dir: '/tmp/test_prompts',
        extname: '.md',
        roles_prefix: 'roles',
        roles_dir: '/tmp/test_prompts/roles',
        role: nil,
        system_prompt: nil
      ),
      flags: OpenStruct.new(
        chat: false,
        no_mcp: false,
        debug: false,
        verbose: false,
        consensus: false,
        tokens: false
      ),
      llm: OpenStruct.new(
        temperature: 0.7,
        max_tokens: 2048,
        top_p: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0
      ),
      tools: OpenStruct.new(
        paths: [],
        allowed: nil,
        rejected: nil
      ),
      output: OpenStruct.new(file: nil, append: false),
      rules: OpenStruct.new(dir: nil, enabled: false)
    )
  end
end
