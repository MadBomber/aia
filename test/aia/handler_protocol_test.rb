# frozen_string_literal: true
# test/aia/handler_protocol_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class HandlerProtocolTest < Minitest::Test
  # =========================================================================
  # HandlerContext
  # =========================================================================

  def test_handler_context_defaults_all_fields_to_nil
    ctx = AIA::HandlerContext.new
    assert_nil ctx.robot
    assert_nil ctx.prompt
    assert_nil ctx.decisions
    assert_nil ctx.config
    assert_nil ctx.specialist_type
  end

  def test_handler_context_accepts_keyword_args
    robot  = Object.new
    ctx = AIA::HandlerContext.new(robot: robot, prompt: "hello", specialist_type: "coder")
    assert_equal robot,   ctx.robot
    assert_equal "hello", ctx.prompt
    assert_equal "coder", ctx.specialist_type
  end

  # =========================================================================
  # HandlerProtocol — base implementation raises NotImplementedError
  # =========================================================================

  def test_protocol_raises_if_handle_not_overridden
    klass = Class.new { include AIA::HandlerProtocol }
    instance = klass.new
    assert_raises(NotImplementedError) do
      instance.handle(AIA::HandlerContext.new)
    end
  end

  # =========================================================================
  # All 5 handlers include HandlerProtocol
  # =========================================================================

  def test_spawn_handler_includes_protocol
    assert AIA::SpawnHandler.include?(AIA::HandlerProtocol)
  end

  def test_debate_handler_includes_protocol
    assert AIA::DebateHandler.include?(AIA::HandlerProtocol)
  end

  def test_delegate_handler_includes_protocol
    assert AIA::DelegateHandler.include?(AIA::HandlerProtocol)
  end

  def test_mention_router_includes_protocol
    assert AIA::MentionRouter.include?(AIA::HandlerProtocol)
  end

  def test_model_switch_handler_includes_protocol
    assert AIA::ModelSwitchHandler.include?(AIA::HandlerProtocol)
  end

  # =========================================================================
  # All 5 handlers respond to handle(context)
  # =========================================================================

  def test_all_handlers_respond_to_handle
    handlers = [
      AIA::SpawnHandler,
      AIA::DebateHandler,
      AIA::DelegateHandler,
      AIA::MentionRouter,
      AIA::ModelSwitchHandler,
    ]
    handlers.each do |klass|
      assert klass.method_defined?(:handle), "#{klass} should define #handle"
    end
  end

end
