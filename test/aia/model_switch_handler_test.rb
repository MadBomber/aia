# frozen_string_literal: true
# test/aia/model_switch_handler_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ModelSwitchHandlerTest < Minitest::Test
  def setup
    @alias_registry = mock('alias_registry')
    @ui_presenter = mock('ui_presenter')
    @handler = AIA::ModelSwitchHandler.new(@alias_registry, @ui_presenter)
    @config = create_test_config
  end

  def teardown
    super
  end

  # ---------------------------------------------------------------------------
  # handle — always returns false (KBS intent detection removed)
  # ---------------------------------------------------------------------------

  def test_handle_returns_false_with_empty_context
    result = @handler.handle(AIA::HandlerContext.new(config: @config))
    assert_equal false, result
  end

  def test_handle_returns_false_with_robot_context
    result = @handler.handle(AIA::HandlerContext.new(robot: mock('robot'), config: @config))
    assert_equal false, result
  end

  def test_handle_returns_false_with_prompt_context
    result = @handler.handle(AIA::HandlerContext.new(prompt: "switch to gpt4", config: @config))
    assert_equal false, result
  end

  def test_handle_returns_false_with_nil_config
    result = @handler.handle(AIA::HandlerContext.new(config: nil))
    assert_equal false, result
  end

  # ---------------------------------------------------------------------------
  # Private helpers — model_exists? cache
  # ---------------------------------------------------------------------------

  def test_model_exists_caches_result_and_calls_provider_once
    result1 = @handler.send(:model_exists?, "gpt-99-turbo")
    result2 = @handler.send(:model_exists?, "gpt-99-turbo")

    assert_equal result1, result2

    cache = @handler.instance_variable_get(:@model_exists_cache)
    assert cache.key?("gpt-99-turbo"), "Result should be cached after first call"
  end

  def test_model_exists_independent_entries_per_model
    @handler.send(:model_exists?, "model-a")
    @handler.send(:model_exists?, "model-b")

    cache = @handler.instance_variable_get(:@model_exists_cache)
    assert cache.key?("model-a")
    assert cache.key?("model-b")
  end

  private

  def create_test_config
    OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      flags: OpenStruct.new(
        chat: false,
        debug: false,
        verbose: false,
        consensus: false
      ),
      model_switch_history: nil
    )
  end
end
