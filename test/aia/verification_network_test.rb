# frozen_string_literal: true

# test/aia/verification_network_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/verification_network'

class VerificationNetworkTest < Minitest::Test
  def setup
    @config = create_test_config
  end

  def test_build_does_not_raise_with_mocked_robot_lab
    mock_network = mock('network')
    mock_robot = mock('robot')

    AIA::RobotFactory.stubs(:build_run_config).returns(
      RobotLab::RunConfig.new(temperature: 0.7, max_tokens: 2048, top_p: 1.0)
    )
    AIA::RobotFactory.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:mcp_servers).returns([])

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
    AIA::RobotFactory.stubs(:mcp_servers).returns([])

    RobotLab.stubs(:build).returns(mock('robot'))
    RobotLab.stubs(:create_network).returns(mock_network)

    # Verify the model is accessed from config
    assert_equal 'gpt-4o-mini', @config.models.first.name

    result = AIA::VerificationNetwork.build(@config)

    refute_nil result
  end

  # --- model assignment and temperature delta (#154) ---

  def test_single_model_is_used_for_all_three_robots
    built = capture_robots(@config)
    assert_equal %w[gpt-4o-mini gpt-4o-mini gpt-4o-mini], built.map { |b| b[:model].name }
  end

  def test_two_models_split_the_verifiers_and_first_reconciles
    @config.models = [model('m0'), model('m1')]
    built = capture_robots(@config)
    assert_equal %w[m0 m1 m0], built.map { |b| b[:model].name }
  end

  def test_three_models_give_each_robot_its_own_model
    @config.models = [model('m0'), model('m1'), model('m2')]
    built = capture_robots(@config)
    assert_equal %w[m0 m1 m2], built.map { |b| b[:model].name }
    assert_equal %w[verifier-a verifier-b reconciler], built.map { |b| b[:name] }
  end

  def test_without_delta_every_robot_uses_the_configured_temperature
    built = capture_robots(@config)
    assert_equal [0.7, 0.7, 0.7], built.map { |b| b[:config].to_h[:temperature] }
  end

  def test_delta_spreads_verifier_temperatures_and_keeps_reconciler
    built = capture_robots(@config, temperature_delta: 0.3)
    assert_equal [0.4, 1.0, 0.7], built.map { |b| b[:config].to_h[:temperature] }
    assert_equal 2048, built.first[:config].to_h[:max_tokens]
  end

  def test_delta_is_clamped_to_valid_temperature_range
    built = capture_robots(@config, temperature_delta: 0.9)
    assert_equal [0.0, 1.0], built.first(2).map { |b| b[:config].to_h[:temperature] }
  end

  def test_delta_is_ignored_when_model_has_no_temperature
    built = capture_robots(@config, run_config: RobotLab::RunConfig.new(max_tokens: 2048),
                                    temperature_delta: 0.3)
    assert_equal [nil, nil, nil], built.map { |b| b[:config].to_h[:temperature] }
  end

  private

  class FakeDSL
    def task(*) = nil
  end

  def model(name)
    OpenStruct.new(name: name, role: nil, internal_id: name)
  end

  def capture_robots(config, run_config: RobotLab::RunConfig.new(temperature: 0.7, max_tokens: 2048),
                     temperature_delta: nil)
    built = []
    AIA::RobotFactory.stubs(:build_run_config).returns(run_config)
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:mcp_servers).returns([])
    AIA::RobotFactory.stubs(:build_robot).with do |model, **opts|
      built << { model: model, name: opts[:name], config: opts[:config] }
      true
    end.returns(Object.new)

    original = RobotLab.method(:create_network)
    RobotLab.define_singleton_method(:create_network) { |**_, &blk| FakeDSL.new.instance_eval(&blk) || :network }
    AIA::VerificationNetwork.build(config, temperature_delta: temperature_delta)
    built
  ensure
    RobotLab.define_singleton_method(:create_network, original) if original
  end

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
