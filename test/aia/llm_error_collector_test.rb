# frozen_string_literal: true

# test/aia/llm_error_collector_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class LLMErrorCollectorTest < Minitest::Test
  Ctx = Struct.new(:robot, :error)
  Bot = Struct.new(:name)

  def setup
    AIA::LLMErrorCollector.reset!
  end

  def teardown
    AIA::LLMErrorCollector.reset!
  end

  def test_is_a_robot_lab_hook_with_a_namespace
    assert AIA::LLMErrorCollector < RobotLab::Hook
    assert_equal :llm_error_collector, AIA::LLMErrorCollector.namespace
  end

  def test_starts_empty
    refute AIA::LLMErrorCollector.errors?
    assert_empty AIA::LLMErrorCollector.errors
  end

  def test_on_error_records_the_robot_and_its_exception
    AIA::LLMErrorCollector.on_error(Ctx.new(Bot.new('Tobor'), RuntimeError.new('invalid x-api-key')))

    assert AIA::LLMErrorCollector.errors?
    entry = AIA::LLMErrorCollector.errors.first
    assert_equal 'Tobor', entry.robot_name
    assert_equal 'invalid x-api-key', entry.error.message
    assert_equal 'Tobor: RuntimeError: invalid x-api-key', entry.to_s
  end

  def test_on_error_copes_with_a_context_that_has_no_robot
    AIA::LLMErrorCollector.on_error(Struct.new(:error).new(RuntimeError.new('boom')))

    assert_equal 'RuntimeError: boom', AIA::LLMErrorCollector.errors.first.to_s
  end

  def test_reset_forgets_recorded_errors
    AIA::LLMErrorCollector.on_error(Ctx.new(Bot.new('Tobor'), RuntimeError.new('boom')))
    AIA::LLMErrorCollector.reset!

    refute AIA::LLMErrorCollector.errors?
  end

  def test_errors_returns_a_copy
    AIA::LLMErrorCollector.on_error(Ctx.new(Bot.new('Tobor'), RuntimeError.new('boom')))
    AIA::LLMErrorCollector.errors.clear

    assert AIA::LLMErrorCollector.errors?
  end

  def test_message_names_the_prompt_and_each_distinct_error
    AIA::LLMErrorCollector.on_error(Ctx.new(Bot.new('Tobor'), RuntimeError.new('rate limited')))
    AIA::LLMErrorCollector.on_error(Ctx.new(Bot.new('Tobor'), RuntimeError.new('rate limited')))
    AIA::LLMErrorCollector.on_error(Ctx.new(Bot.new('Robota'), IOError.new('closed stream')))

    assert_equal "LLM error in prompt 'hi': Tobor: RuntimeError: rate limited; Robota: IOError: closed stream",
                 AIA::LLMErrorCollector.message('hi')
  end

  def test_records_from_several_threads
    threads = 8.times.map do |i|
      Thread.new { AIA::LLMErrorCollector.on_error(Ctx.new(Bot.new("bot#{i}"), RuntimeError.new('boom'))) }
    end
    threads.each(&:join)

    assert_equal 8, AIA::LLMErrorCollector.errors.size
  end

  def test_install_registers_once_on_the_given_registry
    registry = RobotLab::HookRegistry.new

    AIA::LLMErrorCollector.install!(registry)
    AIA::LLMErrorCollector.install!(registry)

    assert_equal [AIA::LLMErrorCollector], registry.registrations.map(&:handler_class)
    assert_equal 1, registry.registrations_for(:on_error).size
  end

  def test_a_hooked_robot_run_that_raises_is_recorded
    registry = RobotLab::HookRegistry.new
    AIA::LLMErrorCollector.install!(registry)
    ctx = RobotLab::RunHookContext.new(robot: Bot.new('Tobor'), request: 'hi')

    assert_raises(RuntimeError) do
      RobotLab::Hooks.run(:run, ctx, registries: [registry]) { raise 'invalid x-api-key' }
    end

    assert_equal 'Tobor: RuntimeError: invalid x-api-key', AIA::LLMErrorCollector.errors.first.to_s
  end
end
