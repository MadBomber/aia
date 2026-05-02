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

  def test_build_run_config_creates_config
    result = AIA::RobotFactory.send(:build_run_config, @config)
    assert_instance_of RobotLab::RunConfig, result
  end

  def test_build_run_config_omits_temperature_for_models_that_do_not_support_it
    @config.models = [OpenStruct.new(name: 'gpt-5.4', role: nil, instance: 1, internal_id: 'gpt-5.4', provider: nil)]
    model_info = OpenStruct.new(provider: 'openai', metadata: { temperature: false })
    RubyLLM.models.expects(:find).with('gpt-5.4').returns(model_info)

    result = AIA::RobotFactory.send(:build_run_config, @config).to_h

    refute_includes result, :temperature
    assert_equal 2048, result[:max_tokens]
  end

  # Task 3: configure_robot_lab must NOT be called during build
  def test_build_does_not_call_configure_robot_lab
    AIA::RobotFactory.expects(:configure_robot_lab).never

    AIA::ToolLoader.stubs(:cached_tools).returns(nil)
    AIA::ToolLoader.stubs(:load_tools)
    mock_robot = mock('robot')
    AIA::RobotFactory.stubs(:build_single_robot).returns(mock_robot)

    AIA::RobotFactory.build(@config)
  end

  # Task 3: setup must call configure_robot_lab exactly once
  def test_setup_calls_configure_robot_lab_once
    AIA::RobotFactory.expects(:configure_robot_lab).with(@config).once
    AIA::RobotFactory.setup(@config)
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

  # Task 4: Each build must get a fresh RobotNamer to avoid used-name state leak.
  # The bug: @namer is a class-level instance variable that persists between
  # build() calls. After the fix, namer must be a local variable passed as a
  # parameter to private helpers rather than stored in @namer.
  def test_each_build_gets_fresh_namer
    namer1 = mock('namer1')
    namer2 = mock('namer2')
    AIA::RobotNamer.expects(:new).with(first_name: 'Tobor').twice.returns(namer1, namer2)

    AIA::ToolLoader.stubs(:cached_tools).returns(nil)
    AIA::ToolLoader.stubs(:load_tools)
    mock_robot = mock('robot')
    AIA::RobotFactory.stubs(:configure_robot_lab)
    AIA::RobotFactory.stubs(:build_single_robot).returns(mock_robot)

    AIA::RobotFactory.build(@config)
    AIA::RobotFactory.build(@config)

    # After the fix, @namer must NOT be set as a class ivar (no leaked state)
    assert_nil AIA::RobotFactory.instance_variable_get(:@namer),
               '@namer should not be stored as a class-level instance variable after the fix'
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
