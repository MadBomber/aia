# frozen_string_literal: true
# test/aia/verification_network_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/verification_network'

class VerificationNetworkTest < Minitest::Test
  def setup
    @config = create_test_config
  end

  def teardown
    super
  end

  def test_build_does_not_raise_with_mocked_robot_lab
    mock_network = mock('network')
    mock_robot = mock('robot')

    AIA::RobotFactory.stubs(:build_run_config).returns(
      RobotLab::RunConfig.new(temperature: 0.7, max_tokens: 2048, top_p: 1.0)
    )
    AIA::RobotFactory.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:mcp_server_configs).returns([])

    RobotLab.stubs(:build).returns(mock_robot)
    RobotLab.stubs(:create_network).returns(mock_network)

    result = AIA::VerificationNetwork.build(@config)

    assert_equal mock_network, result
  end

  def test_build_is_a_class_method
    assert_respond_to AIA::VerificationNetwork, :build
  end

  def test_build_uses_first_model_from_config
    mock_network = mock('network')

    AIA::RobotFactory.stubs(:build_run_config).returns(
      RobotLab::RunConfig.new(temperature: 0.7, max_tokens: 2048, top_p: 1.0)
    )
    AIA::RobotFactory.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:mcp_server_configs).returns([])

    RobotLab.stubs(:build).returns(mock('robot'))
    RobotLab.stubs(:create_network).returns(mock_network)

    # Verify the model is accessed from config
    assert_equal 'gpt-4o-mini', @config.models.first.name

    result = AIA::VerificationNetwork.build(@config)

    refute_nil result
  end

  private

  def create_test_config
    OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil, internal_id: 'gpt-4o-mini')],
      pipeline: [],
      context_files: [],
      mcp_servers: [],
      mcp_use: [],
      mcp_skip: [],
      loaded_tools: [],
      flags: OpenStruct.new(
        chat: false,
        no_mcp: false,
        debug: false,
        verbose: false,
        consensus: false
      ),
      llm: OpenStruct.new(
        temperature: 0.7,
        max_tokens: 2048,
        top_p: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0
      ),
      tools: OpenStruct.new(paths: [], allowed: nil, rejected: nil),
      prompts: OpenStruct.new(
        system_prompt: 'You are helpful',
        role: nil,
        dir: '/tmp/test_prompts',
        extname: '.md',
        roles_prefix: 'roles'
      )
    )
  end
end
