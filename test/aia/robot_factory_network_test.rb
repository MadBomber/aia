# frozen_string_literal: true

# test/aia/robot_factory_network_test.rb
#
# Tests for RobotFactory network build modes:
#   - build_parallel_network (multiple models, no consensus)
#   - build_consensus_network (multiple models + synthesizer)
#   - build_pipeline_network (sequential prompt steps)
#   - build_concurrent_mcp_network (MCP server groups + synthesizer)
#   - build routing (build dispatches to correct builder)

require_relative '../test_helper'
require_relative '../../lib/aia'

class RobotFactoryNetworkTest < Minitest::Test
  def setup
    @config = create_multi_model_config
    AIA.stubs(:config).returns(@config)

    # Pre-populate tool cache to skip ObjectSpace scanning
    AIA::ToolLoader.instance_variable_set(:@tool_cache, [])

    # Stub configure_robot_lab to skip logger/provider setup
    AIA::RobotFactory.stubs(:configure_robot_lab)

    # Initialize the namer (normally done in build)
    AIA::RobotFactory.instance_variable_set(
      :@namer, AIA::RobotNamer.new(first_name: 'Tobor')
    )
  end

  def teardown
    AIA::ToolLoader.clear_cache!
    super
  end

  # =========================================================================
  # build_parallel_network
  # =========================================================================

  def test_parallel_network_returns_a_network
    network = AIA::RobotFactory.send(:build_parallel_network, @config)

    assert_instance_of RobotLab::Network, network
  end

  def test_parallel_network_named_aia_parallel
    network = AIA::RobotFactory.send(:build_parallel_network, @config)

    assert_equal "aia-parallel", network.name
  end

  def test_parallel_network_has_one_robot_per_model
    network = AIA::RobotFactory.send(:build_parallel_network, @config)

    assert_equal 2, network.robots.size
  end

  def test_parallel_network_robots_use_correct_models
    network = AIA::RobotFactory.send(:build_parallel_network, @config)

    models = network.robots.values.map(&:model)
    assert_includes models, 'gpt-4o'
    assert_includes models, 'claude-sonnet-4-20250514'
  end

  def test_parallel_network_robots_have_identity_prompts
    network = AIA::RobotFactory.send(:build_parallel_network, @config)

    network.robots.each_value do |robot|
      prompt = robot.system_prompt
      assert_match(/You are .+, powered by/, prompt,
        "Robot #{robot.name} should have an identity prompt")
      assert_match(/You are part of a team/, prompt,
        "Robot #{robot.name} should know about the team")
    end
  end

  def test_parallel_network_robots_see_full_roster
    network = AIA::RobotFactory.send(:build_parallel_network, @config)

    network.robots.each_value do |robot|
      prompt = robot.system_prompt
      assert_match(/gpt-4o/, prompt, "Roster should include gpt-4o")
      assert_match(/claude-sonnet/, prompt, "Roster should include claude-sonnet")
    end
  end

  def test_parallel_network_has_no_synthesizer
    network = AIA::RobotFactory.send(:build_parallel_network, @config)

    weaver = network.robots.values.find { |r| r.name == "Weaver" }
    assert_nil weaver, "Parallel network should not have a synthesizer"
  end

  # =========================================================================
  # build_consensus_network
  # =========================================================================

  def test_consensus_network_returns_a_network
    network = AIA::RobotFactory.send(:build_consensus_network, @config)

    assert_instance_of RobotLab::Network, network
  end

  def test_consensus_network_named_aia_consensus
    network = AIA::RobotFactory.send(:build_consensus_network, @config)

    assert_equal "aia-consensus", network.name
  end

  def test_consensus_network_has_models_plus_synthesizer
    network = AIA::RobotFactory.send(:build_consensus_network, @config)

    # 2 models + 1 synthesizer = 3
    assert_equal 3, network.robots.size
  end

  def test_consensus_network_has_weaver_synthesizer
    network = AIA::RobotFactory.send(:build_consensus_network, @config)

    weaver = network.robots.values.find { |r| r.name == "Weaver" }
    refute_nil weaver, "Consensus network must have a Weaver synthesizer"
  end

  def test_consensus_synthesizer_has_merge_prompt
    network = AIA::RobotFactory.send(:build_consensus_network, @config)

    weaver = network.robots.values.find { |r| r.name == "Weaver" }
    assert_match(/synthesizer/i, weaver.system_prompt)
    assert_match(/unified.*coherent|coherent.*unified/i, weaver.system_prompt)
  end

  def test_consensus_synthesizer_uses_primary_model
    network = AIA::RobotFactory.send(:build_consensus_network, @config)

    weaver = network.robots.values.find { |r| r.name == "Weaver" }
    assert_equal @config.models.first.name, weaver.model
  end

  def test_consensus_network_robots_have_identity_prompts
    network = AIA::RobotFactory.send(:build_consensus_network, @config)

    non_weaver = network.robots.values.reject { |r| r.name == "Weaver" }
    non_weaver.each do |robot|
      assert_match(/You are part of a team/, robot.system_prompt,
        "Robot #{robot.name} should know about the team")
    end
  end

  # =========================================================================
  # build_pipeline_network
  # =========================================================================

  def test_pipeline_network_returns_a_network
    config = create_pipeline_config
    network = AIA::RobotFactory.send(:build_pipeline_network, config)

    assert_instance_of RobotLab::Network, network
  end

  def test_pipeline_network_named_aia_pipeline
    config = create_pipeline_config
    network = AIA::RobotFactory.send(:build_pipeline_network, config)

    assert_equal "aia-pipeline", network.name
  end

  def test_pipeline_network_has_one_robot_per_step
    config = create_pipeline_config
    network = AIA::RobotFactory.send(:build_pipeline_network, config)

    assert_equal 3, network.robots.size
  end

  def test_pipeline_network_all_robots_use_same_model
    config = create_pipeline_config
    network = AIA::RobotFactory.send(:build_pipeline_network, config)

    models = network.robots.values.map(&:model).uniq
    assert_equal 1, models.size, "All pipeline robots should use the same model"
    assert_equal 'gpt-4o-mini', models.first
  end

  def test_pipeline_with_single_step
    config = create_pipeline_config(prompts: ['analyze'])
    network = AIA::RobotFactory.send(:build_pipeline_network, config)

    assert_equal 1, network.robots.size
  end

  # =========================================================================
  # build_concurrent_mcp_network
  # =========================================================================

  def test_concurrent_mcp_network_returns_a_network
    server_groups = [
      [{ name: 'db_server', transport: { type: 'stdio', command: 'db' } }],
      [{ name: 'api_server', transport: { type: 'stdio', command: 'api' } }]
    ]

    network = AIA::RobotFactory.build_concurrent_mcp_network(@config, server_groups)

    assert_instance_of RobotLab::Network, network
  end

  def test_concurrent_mcp_network_named_aia_concurrent_mcp
    server_groups = [
      [{ name: 'group1', transport: { type: 'stdio', command: 'g1' } }],
      [{ name: 'group2', transport: { type: 'stdio', command: 'g2' } }]
    ]

    network = AIA::RobotFactory.build_concurrent_mcp_network(@config, server_groups)

    assert_equal "aia-concurrent-mcp", network.name
  end

  def test_concurrent_mcp_network_has_workers_plus_synthesizer
    server_groups = [
      [{ name: 'group1', transport: { type: 'stdio', command: 'g1' } }],
      [{ name: 'group2', transport: { type: 'stdio', command: 'g2' } }],
      [{ name: 'group3', transport: { type: 'stdio', command: 'g3' } }]
    ]

    network = AIA::RobotFactory.build_concurrent_mcp_network(@config, server_groups)

    # 3 workers + 1 synthesizer = 4
    assert_equal 4, network.robots.size
  end

  def test_concurrent_mcp_network_has_weaver_synthesizer
    server_groups = [
      [{ name: 'g1', transport: { type: 'stdio', command: 'cmd1' } }],
      [{ name: 'g2', transport: { type: 'stdio', command: 'cmd2' } }]
    ]

    network = AIA::RobotFactory.build_concurrent_mcp_network(@config, server_groups)

    weaver = network.robots.values.find { |r| r.name == "Weaver" }
    refute_nil weaver, "Concurrent MCP network must have a Weaver synthesizer"
  end

  def test_concurrent_mcp_synthesizer_has_merge_prompt
    server_groups = [
      [{ name: 'g1', transport: { type: 'stdio', command: 'cmd1' } }],
      [{ name: 'g2', transport: { type: 'stdio', command: 'cmd2' } }]
    ]

    network = AIA::RobotFactory.build_concurrent_mcp_network(@config, server_groups)

    weaver = network.robots.values.find { |r| r.name == "Weaver" }
    assert_match(/synthesizer/i, weaver.system_prompt)
    assert_match(/merge/i, weaver.system_prompt)
  end

  # =========================================================================
  # build dispatch routing
  # =========================================================================

  def test_build_routes_single_model_to_single_robot
    single_config = create_single_model_config
    AIA.stubs(:config).returns(single_config)

    result = AIA::RobotFactory.build(single_config)

    assert_instance_of RobotLab::Robot, result,
      "Single model should build a Robot, not a Network"
  end

  def test_build_routes_multi_model_no_consensus_to_parallel
    @config.flags.consensus = false

    result = AIA::RobotFactory.build(@config)

    assert_instance_of RobotLab::Network, result
    assert_equal "aia-parallel", result.name
  end

  def test_build_routes_multi_model_with_consensus_to_consensus
    @config.flags.consensus = true

    result = AIA::RobotFactory.build(@config)

    assert_instance_of RobotLab::Network, result
    assert_equal "aia-consensus", result.name
  end

  def test_build_routes_pipeline_to_pipeline_network
    config = create_pipeline_config
    AIA.stubs(:config).returns(config)

    result = AIA::RobotFactory.build(config)

    assert_instance_of RobotLab::Network, result
    assert_equal "aia-pipeline", result.name
  end

  def test_build_pipeline_takes_precedence_over_multi_model
    config = create_pipeline_config
    config.models = [
      OpenStruct.new(name: 'gpt-4o', role: nil, instance: 1, internal_id: 'gpt-4o', provider: nil),
      OpenStruct.new(name: 'claude-sonnet-4-20250514', role: nil, instance: 1, internal_id: 'claude-sonnet-4-20250514', provider: nil)
    ]
    AIA.stubs(:config).returns(config)

    result = AIA::RobotFactory.build(config)

    assert_equal "aia-pipeline", result.name,
      "Pipeline should take precedence over multi-model when both are configured"
  end

  # =========================================================================
  # initialize_network_memory
  # =========================================================================

  def test_network_memory_initialized_with_session_context
    network = AIA::RobotFactory.send(:build_parallel_network, @config)
    AIA::RobotFactory.send(:initialize_network_memory, network, @config)

    memory = network.memory
    refute_nil memory.data.session_id
    assert_equal 2, memory.data.model_count
    assert_equal %w[gpt-4o claude-sonnet-4-20250514], memory.data.model_names
    assert_equal 0, memory.data.turn_count
  end

  def test_network_memory_mode_parallel_when_no_consensus
    @config.flags.consensus = false
    network = AIA::RobotFactory.send(:build_parallel_network, @config)
    AIA::RobotFactory.send(:initialize_network_memory, network, @config)

    assert_equal :parallel, network.memory.data.mode
  end

  def test_network_memory_mode_consensus_when_consensus_enabled
    @config.flags.consensus = true
    network = AIA::RobotFactory.send(:build_consensus_network, @config)
    AIA::RobotFactory.send(:initialize_network_memory, network, @config)

    assert_equal :consensus, network.memory.data.mode
  end

  # =========================================================================
  # setup_memory_subscriptions
  # =========================================================================

  def test_memory_subscriptions_set_completed_count
    network = AIA::RobotFactory.send(:build_parallel_network, @config)
    AIA::RobotFactory.send(:initialize_network_memory, network, @config)
    AIA::RobotFactory.send(:setup_memory_subscriptions, network, @config)

    assert_equal 0, network.memory.get(:completed_count)
  end

  # =========================================================================
  # build_identity_prompt
  # =========================================================================

  def test_identity_prompt_single_robot
    spec = OpenStruct.new(name: 'gpt-4o', provider: nil)
    roster = [{ name: 'Tobor', spec: spec }]

    prompt = AIA::SystemPromptAssembler.build_identity_prompt('Tobor', spec, roster)

    assert_match(/You are Tobor, powered by gpt-4o/, prompt)
    refute_match(/team/, prompt, "Single robot should not mention a team")
  end

  def test_identity_prompt_multi_robot_shows_roster
    spec1 = OpenStruct.new(name: 'gpt-4o', provider: nil)
    spec2 = OpenStruct.new(name: 'claude-sonnet-4-20250514', provider: nil)
    roster = [
      { name: 'Tobor', spec: spec1 },
      { name: 'Spark', spec: spec2 }
    ]

    prompt = AIA::SystemPromptAssembler.build_identity_prompt('Tobor', spec1, roster)

    assert_match(/You are part of a team/, prompt)
    assert_match(/Tobor.*← you/, prompt)
    assert_match(/Spark/, prompt)
    assert_match(/@name mentions/, prompt)
  end

  def test_identity_prompt_includes_provider_when_present
    spec = OpenStruct.new(name: 'llama3', provider: 'ollama')
    roster = [{ name: 'Tobor', spec: spec }]

    prompt = AIA::SystemPromptAssembler.build_identity_prompt('Tobor', spec, roster)

    assert_match(/\(ollama\)/, prompt)
  end

  private

  def create_multi_model_config
    OpenStruct.new(
      models: [
        OpenStruct.new(name: 'gpt-4o', role: nil, instance: 1, internal_id: 'gpt-4o', provider: nil),
        OpenStruct.new(name: 'claude-sonnet-4-20250514', role: nil, instance: 1, internal_id: 'claude-sonnet-4-20250514', provider: nil)
      ],
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

  def create_single_model_config
    config = create_multi_model_config
    config.models = [
      OpenStruct.new(name: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini', provider: nil)
    ]
    config
  end

  def create_pipeline_config(prompts: ['analyze', 'write', 'review'])
    config = create_multi_model_config
    config.models = [
      OpenStruct.new(name: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini', provider: nil)
    ]
    config.pipeline = prompts
    config
  end
end
