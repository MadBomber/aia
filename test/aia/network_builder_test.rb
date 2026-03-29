# frozen_string_literal: true

# test/aia/network_builder_test.rb
#
# Unit tests for AIA::NetworkBuilder.
# Focuses on observable collaborator interactions via mocks,
# complementing the integration-level coverage in robot_factory_network_test.rb.

require_relative '../test_helper'
require_relative '../../lib/aia'

class NetworkBuilderTest < Minitest::Test
  def setup
    # Single model spec used for pipeline tests
    @model_spec = OpenStruct.new(
      name:        'gpt-4o-mini',
      role:        nil,
      provider:    nil,
      internal_id: 'gpt-4o-mini',
      instance:    1
    )

    @config = OpenStruct.new(
      pipeline:       ['prompt_a', 'prompt_b'],
      models:         [@model_spec],
      context_files:  [],
      mcp_servers:    [],
      mcp_use:        [],
      mcp_skip:       [],
      require_libs:   [],
      loaded_tools:   [],
      tool_names:     '',
      prompts: OpenStruct.new(
        dir:          '/tmp/test_prompts',
        extname:      '.md',
        roles_prefix: 'roles',
        roles_dir:    '/tmp/test_prompts/roles',
        role:         nil,
        system_prompt: nil
      ),
      flags: OpenStruct.new(
        chat:       false,
        no_mcp:     false,
        debug:      false,
        verbose:    false,
        consensus:  false,
        tokens:     false
      ),
      llm: OpenStruct.new(
        temperature:       0.7,
        max_tokens:        2048,
        top_p:             1.0,
        frequency_penalty: 0.0,
        presence_penalty:  0.0
      ),
      tools: OpenStruct.new(paths: [], allowed: nil, rejected: nil),
      output: OpenStruct.new(file: nil, append: false),
      rules:  OpenStruct.new(dir: nil, enabled: false)
    )

    @namer = AIA::RobotNamer.new(first_name: 'Tobor')

    # Pre-populate tool cache so ToolLoader doesn't scan ObjectSpace
    AIA::ToolLoader.instance_variable_set(:@tool_cache, [])

    AIA.stubs(:config).returns(@config)
  end

  def teardown
    AIA::ToolLoader.clear_cache!
    super
  end

  # =========================================================================
  # build_pipeline_network — name assertion
  # =========================================================================

  def test_build_pipeline_network_calls_create_network_with_aia_pipeline_name
    network = AIA::NetworkBuilder.build_pipeline_network(@config, @namer)

    assert_equal "aia-pipeline", network.name,
      "build_pipeline_network must create a network named 'aia-pipeline'"
  end

  # =========================================================================
  # build_pipeline_network — robot count
  # =========================================================================

  def test_build_pipeline_network_builds_one_robot_per_pipeline_step
    @config.pipeline = ['step_one', 'step_two', 'step_three']

    network = AIA::NetworkBuilder.build_pipeline_network(@config, @namer)

    assert_equal 3, network.robots.size,
      "Pipeline network should have exactly one robot per pipeline step"
  end

  # =========================================================================
  # build_parallel_network — name assertion
  # =========================================================================

  def test_build_parallel_network_calls_create_network_with_aia_parallel_name
    # Two models required so parallel is meaningful; each needs internal_id.
    # Use real model names known to RubyLLM to avoid ModelNotFoundError.
    @config.models = [
      OpenStruct.new(name: 'gpt-4o',                    role: nil, provider: nil, internal_id: 'gpt-4o',                    instance: 1),
      OpenStruct.new(name: 'claude-sonnet-4-20250514',  role: nil, provider: nil, internal_id: 'claude-sonnet-4-20250514',  instance: 1)
    ]

    network = AIA::NetworkBuilder.build_parallel_network(@config, @namer)

    assert_equal "aia-parallel", network.name,
      "build_parallel_network must create a network named 'aia-parallel'"
  end

  # =========================================================================
  # build_parallel_network — namer consulted for each model
  # =========================================================================

  def test_build_parallel_network_uses_namer_for_each_model_name
    model_names = ['gpt-4o', 'claude-sonnet-4-20250514']
    @config.models = model_names.map do |n|
      OpenStruct.new(name: n, role: nil, provider: nil, internal_id: n, instance: 1)
    end

    names_requested = []
    tracking_namer = Object.new
    tracking_namer.define_singleton_method(:name_for) do |n|
      names_requested << n
      "robot-#{n}"
    end

    AIA::NetworkBuilder.build_parallel_network(@config, tracking_namer)

    model_names.each do |expected|
      assert_includes names_requested, expected,
        "namer.name_for should have been called with '#{expected}'"
    end
  end
end
