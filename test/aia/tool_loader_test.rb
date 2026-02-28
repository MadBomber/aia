# frozen_string_literal: true
# test/aia/tool_loader_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ToolLoaderTest < Minitest::Test
  def setup
    @config = create_test_config
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:turn_state).returns(OpenStruct.new(active_tools: nil))
  end

  def teardown
    AIA::ToolLoader.clear_cache!
    super
  end

  def test_cached_tools_returns_nil_when_empty
    AIA::ToolLoader.clear_cache!
    assert_nil AIA::ToolLoader.cached_tools
  end

  def test_cached_tools_returns_cache_after_load
    AIA::ToolLoader.load_tools(@config)
    assert_kind_of Array, AIA::ToolLoader.cached_tools
  end

  def test_clear_cache_resets_cache
    AIA::ToolLoader.load_tools(@config)
    refute_nil AIA::ToolLoader.cached_tools

    AIA::ToolLoader.clear_cache!
    assert_nil AIA::ToolLoader.cached_tools
  end

  def test_load_tools_populates_cache
    AIA::ToolLoader.clear_cache!
    AIA::ToolLoader.load_tools(@config)

    cache = AIA::ToolLoader.cached_tools
    assert_kind_of Array, cache
  end

  def test_filtered_tools_returns_empty_when_no_tools
    @config.loaded_tools = []
    result = AIA::ToolLoader.filtered_tools(@config)
    assert_equal [], result
  end

  def test_filtered_tools_deduplicates_by_name
    tool1 = mock('tool1')
    tool1.stubs(:name).returns('MyTool')
    tool2 = mock('tool2')
    tool2.stubs(:name).returns('MyTool')

    @config.loaded_tools = [tool1, tool2]
    result = AIA::ToolLoader.filtered_tools(@config)
    assert_equal 1, result.length
  end

  def test_filtered_tools_applies_allowed_filter
    tool1 = mock('tool1')
    tool1.stubs(:name).returns('AllowedTool')
    tool2 = mock('tool2')
    tool2.stubs(:name).returns('RejectedTool')

    @config.loaded_tools = [tool1, tool2]
    @config.tools.allowed = ['allowed']

    result = AIA::ToolLoader.filtered_tools(@config)
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

    result = AIA::ToolLoader.filtered_tools(@config)
    assert_equal 1, result.length
    assert_equal 'GoodTool', result.first.name
  end

  def test_discover_tools_skips_unavailable_tools
    unavailable_tool_class = Class.new(RubyLLM::Tool) do
      def self.name = 'unavailable_tool'
      description "A tool that is not available"
      def available?
        false
      end
    end

    available_tool_class = Class.new(RubyLLM::Tool) do
      def self.name = 'available_tool'
      description "A tool that is available"
      def available?
        true
      end
    end

    tools = AIA::ToolLoader.discover_tools

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
    basic_tool_class = Class.new(RubyLLM::Tool) do
      def self.name = 'basic_tool'
      description "A basic tool without available? method"
    end

    tools = AIA::ToolLoader.discover_tools

    assert_includes tools, basic_tool_class,
                    "Tools without available? should be included"
  ensure
    basic_tool_class = nil
    GC.start
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
