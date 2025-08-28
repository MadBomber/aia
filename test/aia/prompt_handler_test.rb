require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class PromptHandlerTest < Minitest::Test
  def setup
    # Mock AIA module methods to prevent actual operations
    AIA.stubs(:config).returns(OpenStruct.new(
      model: 'test-model',
      temperature: 0.7,
      max_tokens: 2048,
      chat: false,
      tools: [],
      context_files: [],
      prompts_dir: '/tmp/test_prompts',
      role: nil,
      prompt_id: 'test_prompt',
      fuzzy: false
    ))
    
    @handler = AIA::PromptHandler.new
  end

  def test_initialization
    # Test basic initialization
    assert_instance_of AIA::PromptHandler, @handler
  end

  def test_basic_functionality
    # Test that handler has expected methods
    assert_respond_to @handler, :get_prompt
    assert_respond_to @handler, :fetch_prompt
    assert_respond_to @handler, :fetch_role
  end

  def test_handler_with_valid_config
    # Test that handler works with valid configuration
    handler = AIA::PromptHandler.new
    assert_instance_of AIA::PromptHandler, handler
  end

  def test_handler_methods_exist
    # Test that core methods exist and are callable
    handler = AIA::PromptHandler.new
    
    # These methods should exist
    assert handler.respond_to?(:get_prompt)
    assert handler.respond_to?(:fetch_prompt)
    assert handler.respond_to?(:fetch_role)
  end
end