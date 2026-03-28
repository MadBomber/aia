# frozen_string_literal: true
# test/aia/robot_builder_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/robot_builder'
require_relative '../../lib/aia/mcp_config_normalizer'

class RobotBuilderTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil, provider: nil)],
      mcp_servers: [], mcp_use: [], mcp_skip: [],
      flags: OpenStruct.new(no_mcp: true, debug: false, verbose: false),
      loaded_tools: [], tool_names: '',
      tools: OpenStruct.new(paths: [], allowed: nil, rejected: nil),
      llm: OpenStruct.new(
        temperature: 0.7, max_tokens: 2048, top_p: 1.0,
        frequency_penalty: 0.0, presence_penalty: 0.0
      ),
      prompts: OpenStruct.new(
        system_prompt: nil, role: nil,
        dir: '/tmp', extname: '.md', roles_prefix: 'roles', roles_dir: '/tmp/roles'
      ),
      rules: OpenStruct.new(dir: nil, enabled: false),
      output: OpenStruct.new(file: nil, append: false)
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:turn_state).returns(AIA::TurnState.new)

    @namer = mock('namer')
    @namer.stubs(:name_for).returns("Tobor")
  end

  def test_build_returns_robot
    mock_robot = mock('robot')
    RobotLab.stubs(:build).returns(mock_robot)
    AIA::SystemPromptAssembler.stubs(:build_identity_prompt).returns("identity")
    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).returns("base")
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::MCPConfigNormalizer.stubs(:filter_servers).returns([])

    result = AIA::RobotBuilder.build(@config, namer: @namer)
    assert_equal mock_robot, result
  end

  def test_build_uses_namer_for_robot_name
    captured_name = nil
    RobotLab.stubs(:build).with { |opts| captured_name = opts[:name]; true }.returns(mock('robot'))
    AIA::SystemPromptAssembler.stubs(:build_identity_prompt).returns("id")
    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).returns(nil)
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::MCPConfigNormalizer.stubs(:filter_servers).returns([])

    AIA::RobotBuilder.build(@config, namer: @namer)
    assert_equal "Tobor", captured_name
  end
end
