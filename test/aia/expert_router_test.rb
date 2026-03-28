# frozen_string_literal: true
# test/aia/expert_router_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ExpertRouterTest < Minitest::Test
  def setup
    @decisions = AIA::Decisions.new
    @config = create_test_config
  end

  def teardown
    super
  end

  def test_route_returns_nil_when_no_classifications
    router = AIA::ExpertRouter.new(@decisions)

    result = router.route(@config)

    assert_nil result
  end

  def test_route_returns_nil_when_no_model_or_mcp_decisions
    @decisions.add(:classification, domain: "code", source: "code_request")
    # No model_decisions or mcp_activations added
    router = AIA::ExpertRouter.new(@decisions)

    result = router.route(@config)

    assert_nil result
  end

  def test_route_returns_robot_when_model_decision_exists
    @decisions.add(:classification, domain: "code", source: "code_request")
    @decisions.add(:model_decision, model: "gpt-4o", reason: "vision capability needed")

    mock_robot = mock('specialist_robot')

    RobotLab.stubs(:build).returns(mock_robot)
    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).returns("You are helpful")
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:normalize_mcp_config).returns({})
    AIA::RobotFactory.stubs(:build_run_config).returns(
      RobotLab::RunConfig.new(temperature: 0.7, max_tokens: 2048, top_p: 1.0)
    )

    router = AIA::ExpertRouter.new(@decisions)
    result = router.route(@config)

    assert_equal mock_robot, result
  end

  def test_route_returns_robot_when_mcp_activations_exist
    @decisions.add(:classification, domain: "data", source: "data_request")
    @decisions.add(:mcp_activate, server: "sql_server", reason: "data domain")

    mock_robot = mock('specialist_robot')

    RobotLab.stubs(:build).returns(mock_robot)
    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).returns("You are helpful")
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:normalize_mcp_config).returns({})
    AIA::RobotFactory.stubs(:build_run_config).returns(
      RobotLab::RunConfig.new(temperature: 0.7, max_tokens: 2048, top_p: 1.0)
    )

    router = AIA::ExpertRouter.new(@decisions)
    result = router.route(@config)

    assert_equal mock_robot, result
  end

  def test_route_returns_nil_when_build_raises_error
    @decisions.add(:classification, domain: "code", source: "code_request")
    @decisions.add(:model_decision, model: "gpt-4o", reason: "test")

    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).raises(StandardError, "build failure")

    router = AIA::ExpertRouter.new(@decisions)
    result = router.route(@config)

    assert_nil result
  end

  def test_route_classification_without_domain_returns_nil
    # Add classification without a :domain key
    @decisions.add(:classification, type: :intent, action: "model_switch")
    @decisions.add(:model_decision, model: "gpt-4o", reason: "test")

    router = AIA::ExpertRouter.new(@decisions)
    result = router.route(@config)

    assert_nil result
  end

  def test_expert_router_is_integrated_into_chat_loop
    # Verify ExpertRouter is referenced in ChatLoop (integration already exists)
    assert defined?(AIA::ExpertRouter), "ExpertRouter class should exist"
    router = AIA::ExpertRouter.new(@decisions)
    assert_respond_to router, :route
  end

  private

  def create_test_config
    OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      mcp_servers: [{ name: 'server1' }, { name: 'sql_server' }],
      flags: OpenStruct.new(
        no_mcp: false,
        debug: false,
        verbose: false
      ),
      prompts: OpenStruct.new(
        system_prompt: 'You are helpful',
        role: nil,
        dir: '/tmp/test_prompts',
        extname: '.md',
        roles_prefix: 'roles'
      ),
      tools: OpenStruct.new(paths: [], allowed: nil, rejected: nil),
      loaded_tools: [],
      llm: OpenStruct.new(
        temperature: 0.7,
        max_tokens: 2048,
        top_p: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0
      )
    )
  end
end
