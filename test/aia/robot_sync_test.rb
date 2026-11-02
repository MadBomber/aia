# frozen_string_literal: true

# test/aia/robot_sync_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require 'ostruct'

class RobotSyncTest < Minitest::Test
  # A factory whose llm_params mirror config.llm and whose rebuild returns a new client.
  class FakeFactory
    attr_reader :rebuilds

    def initialize
      @rebuilds = []
    end

    def llm_params(config)
      config.llm.to_h.compact
    end

    def rebuild(config, history_mode:)
      @rebuilds << history_mode
      Object.new
    end
  end

  def setup
    @config = OpenStruct.new(
      models: AIA::Config::TO_MODEL_SPECS.call(['gpt-4o-mini']),
      llm: OpenStruct.new(temperature: 0.7),
      model_switch_history: 'clean'
    )
    @robot   = mock('robot')
    @factory = FakeFactory.new
    @sync    = AIA::RobotSync.new(@config, @robot, factory: @factory)
    AIA.stubs(:client=)
  end

  def test_unchanged_config_keeps_client
    assert_same @robot, @sync.call(@robot)
    assert_empty @factory.rebuilds
  end

  def test_llm_change_retunes_in_place
    @config.llm.temperature = 0.2
    @robot.expects(:update).with(temperature: 0.2, provider_options: {})
    assert_same @robot, @sync.call(@robot)
    assert_empty @factory.rebuilds
  end

  def test_retune_happens_once
    @config.llm.temperature = 0.2
    @robot.expects(:update).once
    @sync.call(@robot)
    @sync.call(@robot)
  end

  def test_model_change_rebuilds_with_history_mode
    @config.models = AIA::Config::TO_MODEL_SPECS.call(['claude-haiku-4-5'])
    new_client = @sync.call(@robot)
    refute_same @robot, new_client
    assert_equal [:clean], @factory.rebuilds
    assert_same new_client, @sync.call(new_client)
  end

  def test_client_replaced_elsewhere_becomes_baseline
    other = mock('other')
    @config.models = AIA::Config::TO_MODEL_SPECS.call(['claude-haiku-4-5'])
    assert_same other, @sync.call(other)
    assert_empty @factory.rebuilds
  end

  def test_update_options_maps_params
    options = AIA::RobotSync.update_options(temperature: 0.3, max_tokens: 100, top_p: 0.9, presence_penalty: 0.1)
    assert_equal({ temperature: 0.3, max_output_tokens: 100, provider_options: { top_p: 0.9, presence_penalty: 0.1 } }, options)
    assert_equal({ provider_options: {} }, AIA::RobotSync.update_options({}))
  end

  def test_retune_updates_every_crew_member
    first  = mock('first')
    second = mock('second')
    crew   = OpenStruct.new(crew: [first, second])
    sync   = AIA::RobotSync.new(@config, crew, factory: @factory)
    @config.llm.temperature = 0.1
    first.expects(:update).with(temperature: 0.1, provider_options: {})
    second.expects(:update).with(temperature: 0.1, provider_options: {})
    sync.call(crew)
  end
end
