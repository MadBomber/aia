require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class PromptHandlerTest < Minitest::Test
  def setup
    # Mock AIA module methods to prevent actual operations
    AIA.stubs(:config).returns(OpenStruct.new(
      models: [OpenStruct.new(name: 'test-model')],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      prompts: OpenStruct.new(
        dir: '/tmp/test_prompts',
        extname: '.txt',
        roles_dir: '/tmp/test_prompts/roles',
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: '\\{\\{\\w+\\}\\}'
      ),
      prompt_id: 'test_prompt'
    ))

    @handler = AIA::PromptHandler.new
  end

  def teardown
    # Call super to ensure Mocha cleanup runs
    super
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