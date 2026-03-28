# frozen_string_literal: true
# test/aia/model_switch_handler_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ModelSwitchHandlerTest < Minitest::Test
  def setup
    @alias_registry = mock('alias_registry')
    @ui_presenter = mock('ui_presenter')
    @handler = AIA::ModelSwitchHandler.new(@alias_registry, @ui_presenter)
    @decisions = AIA::Decisions.new
    @config = create_test_config
  end

  def teardown
    super
  end

  def test_handle_returns_false_when_no_intent_in_decisions
    # Only add a non-intent classification
    @decisions.add(:classification, domain: "code", source: "code_request")

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal false, result
  end

  def test_handle_returns_false_when_intent_has_unknown_action
    @decisions.add(:classification,
      type: :intent,
      action: "unknown_action",
      raw_text: "do something weird"
    )

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal false, result
  end

  def test_handle_with_model_switch_intent_extracts_models
    @decisions.add(:classification,
      type: :intent,
      action: "model_switch",
      raw_text: "switch to claude"
    )

    @alias_registry.stubs(:known?).with('switch').returns(false)
    @alias_registry.stubs(:known?).with('to').returns(false)
    @alias_registry.stubs(:known?).with('claude').returns(true)
    @alias_registry.stubs(:resolve).with('claude').returns('claude-sonnet-4-20250514')

    # display_info is called 3 times: "Interpreted as...", "Proceed?", and "Model switched to..."
    display_messages = []
    @ui_presenter.stubs(:display_info).with { |msg| display_messages << msg; true }
    @ui_presenter.stubs(:ask_question).returns('y')

    # Mock the apply_model_change path
    AIA::RobotFactory.stubs(:rebuild).returns(mock('new_robot'))
    AIA.stubs(:client=)

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal true, result
    assert display_messages.any? { |m| m =~ /Interpreted as.*claude-sonnet-4-20250514/ },
      "Expected display_info to be called with model name, got: #{display_messages.inspect}"
    assert display_messages.any? { |m| m == "Proceed? (y/n)" },
      "Expected display_info to be called with 'Proceed? (y/n)'"
  end

  def test_handle_with_model_switch_returns_false_when_user_declines
    @decisions.add(:classification,
      type: :intent,
      action: "model_switch",
      raw_text: "switch to claude"
    )

    @alias_registry.stubs(:known?).with('switch').returns(false)
    @alias_registry.stubs(:known?).with('to').returns(false)
    @alias_registry.stubs(:known?).with('claude').returns(true)
    @alias_registry.stubs(:resolve).with('claude').returns('claude-sonnet-4-20250514')

    @ui_presenter.stubs(:display_info)
    @ui_presenter.expects(:ask_question).returns('n')

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal false, result
  end

  def test_handle_with_model_switch_returns_false_when_no_models_extracted
    @decisions.add(:classification,
      type: :intent,
      action: "model_switch",
      raw_text: "switch to something"
    )

    @alias_registry.stubs(:known?).returns(false)

    # model_exists? checks - stub RubyLLM to return nil
    if defined?(RubyLLM)
      RubyLLM.stubs(:respond_to?).with(:models).returns(false)
    end

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal false, result
  end

  def test_handle_returns_false_when_exception_raised
    @decisions.add(:classification,
      type: :intent,
      action: "model_switch",
      raw_text: nil  # Will cause extract_model_names to return []
    )

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal false, result
  end

  def test_handle_with_model_compare_intent
    @decisions.add(:classification,
      type: :intent,
      action: "model_compare",
      raw_text: "compare claude and gpt4"
    )

    @alias_registry.stubs(:known?).with('compare').returns(false)
    @alias_registry.stubs(:known?).with('claude').returns(true)
    @alias_registry.stubs(:known?).with('and').returns(false)
    @alias_registry.stubs(:known?).with('gpt4').returns(true)
    @alias_registry.stubs(:resolve).with('claude').returns('claude-sonnet-4-20250514')
    @alias_registry.stubs(:resolve).with('gpt4').returns('gpt-4o')

    @ui_presenter.stubs(:display_info)
    @ui_presenter.expects(:ask_question).returns('y')

    AIA::RobotFactory.stubs(:rebuild).returns(mock('new_robot'))
    AIA.stubs(:client=)

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal true, result
  end

  def test_handle_with_capability_switch_intent
    @decisions.add(:classification,
      type: :intent,
      action: "model_switch_capability",
      capability: "fast",
      raw_text: "use a fast model"
    )

    @alias_registry.stubs(:resolve).with('fast').returns('claude-haiku-4-5-20251001')

    @ui_presenter.stubs(:display_info)
    @ui_presenter.expects(:ask_question).returns('y')

    AIA::RobotFactory.stubs(:rebuild).returns(mock('new_robot'))
    AIA.stubs(:client=)

    result = @handler.handle(AIA::HandlerContext.new(decisions: @decisions, config: @config))

    assert_equal true, result
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
