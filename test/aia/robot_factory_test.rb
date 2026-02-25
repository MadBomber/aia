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

  def test_filtered_tools_returns_empty_when_no_tools
    @config.loaded_tools = []
    result = AIA::RobotFactory.send(:filtered_tools, @config)
    assert_equal [], result
  end

  def test_filtered_tools_deduplicates_by_name
    tool1 = mock('tool1')
    tool1.stubs(:name).returns('MyTool')
    tool2 = mock('tool2')
    tool2.stubs(:name).returns('MyTool')

    @config.loaded_tools = [tool1, tool2]
    result = AIA::RobotFactory.send(:filtered_tools, @config)
    assert_equal 1, result.length
  end

  def test_filtered_tools_applies_allowed_filter
    tool1 = mock('tool1')
    tool1.stubs(:name).returns('AllowedTool')
    tool2 = mock('tool2')
    tool2.stubs(:name).returns('RejectedTool')

    @config.loaded_tools = [tool1, tool2]
    @config.tools.allowed = ['allowed']

    result = AIA::RobotFactory.send(:filtered_tools, @config)
    assert_equal 1, result.length
    assert_equal 'AllowedTool', result.first.name
  end

  def test_filtered_tools_applies_rejected_filter
    tool1 = mock('tool1')
    tool1.stubs(:name).returns('GoodTool')
    tool2 = mock('tool2')
    tool2.stubs(:name).returns('BadTool')

    @config.loaded_tools = [tool1, tool2]
    @config.tools.rejected = ['bad']

    result = AIA::RobotFactory.send(:filtered_tools, @config)
    assert_equal 1, result.length
    assert_equal 'GoodTool', result.first.name
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

  def test_resolve_system_prompt_with_no_role
    @config.prompts.system_prompt = 'You are helpful'
    @config.prompts.role = nil

    model_spec = OpenStruct.new(name: 'gpt-4o', role: nil)
    result = AIA::RobotFactory.send(:resolve_system_prompt, @config, model_spec)
    assert_equal 'You are helpful', result
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

  # I4/I5: Tool caching tests
  def test_clear_tool_cache_resets_cache
    # Set up a cache
    AIA::RobotFactory.instance_variable_set(:@tool_cache, [:fake_tool])
    assert_equal [:fake_tool], AIA::RobotFactory.instance_variable_get(:@tool_cache)

    AIA::RobotFactory.clear_tool_cache!
    assert_nil AIA::RobotFactory.instance_variable_get(:@tool_cache)
  end

  def test_load_tools_populates_cache
    AIA::RobotFactory.clear_tool_cache!
    AIA::RobotFactory.send(:load_tools, @config)

    cache = AIA::RobotFactory.instance_variable_get(:@tool_cache)
    assert_kind_of Array, cache
  end

  def test_discover_tools_skips_unavailable_tools
    # Create a tool class that reports itself as unavailable
    unavailable_tool_class = Class.new(RubyLLM::Tool) do
      def self.name = 'unavailable_tool'
      description "A tool that is not available"
      def available?
        false
      end
    end

    # Create a tool class that reports itself as available
    available_tool_class = Class.new(RubyLLM::Tool) do
      def self.name = 'available_tool'
      description "A tool that is available"
      def available?
        true
      end
    end

    # discover_tools returns Class objects via ObjectSpace
    tools = AIA::RobotFactory.send(:discover_tools)

    refute_includes tools, unavailable_tool_class,
                    "Unavailable tool should be filtered out"
    assert_includes tools, available_tool_class,
                    "Available tool should be included"
  ensure
    unavailable_tool_class = nil
    available_tool_class = nil
    GC.start
  end

  def test_discover_tools_includes_tools_without_available_method
    # Tools that don't implement available? should be included (backward compat)
    basic_tool_class = Class.new(RubyLLM::Tool) do
      def self.name = 'basic_tool'
      description "A basic tool without available? method"
    end

    tools = AIA::RobotFactory.send(:discover_tools)

    assert_includes tools, basic_tool_class,
                    "Tools without available? should be included"
  ensure
    basic_tool_class = nil
    GC.start
  end

  def test_build_skips_load_tools_when_cache_exists
    tool = mock('cached_tool')
    tool.stubs(:name).returns('CachedTool')
    AIA::RobotFactory.instance_variable_set(:@tool_cache, [tool])

    # build() should assign cached tools to config without calling load_tools
    AIA::RobotFactory.stubs(:configure_robot_lab)
    AIA::RobotFactory.expects(:load_tools).never

    # Stub the actual robot building
    mock_robot = mock('robot')
    AIA::RobotFactory.stubs(:build_single_robot).returns(mock_robot)

    AIA::RobotFactory.build(@config)

    assert_equal [tool], @config.loaded_tools
    assert_equal 'CachedTool', @config.tool_names
  ensure
    AIA::RobotFactory.clear_tool_cache!
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
