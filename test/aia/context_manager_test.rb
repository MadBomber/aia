require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class ContextManagerTest < Minitest::Test
  def setup
    # Mock AIA.config to prevent external dependencies
    AIA.stubs(:config).returns(OpenStruct.new(
      client: nil,
      llm: nil
    ))
  end

  def test_initialization_without_system_prompt
    manager = AIA::ContextManager.new
    
    assert_instance_of AIA::ContextManager, manager
    assert_empty manager.context
  end

  def test_initialization_with_system_prompt
    manager = AIA::ContextManager.new(system_prompt: 'You are a helpful assistant')
    
    assert_equal 1, manager.context.size
    assert_equal 'system', manager.context.first[:role]
    assert_equal 'You are a helpful assistant', manager.context.first[:content]
  end

  def test_initialization_with_empty_system_prompt
    manager = AIA::ContextManager.new(system_prompt: '  ')
    
    assert_empty manager.context
  end

  def test_initialization_with_nil_system_prompt
    manager = AIA::ContextManager.new(system_prompt: nil)
    
    assert_empty manager.context
  end

  def test_add_to_context
    manager = AIA::ContextManager.new
    
    manager.add_to_context(role: 'user', content: 'Hello')
    manager.add_to_context(role: 'assistant', content: 'Hi there!')
    
    assert_equal 2, manager.context.size
    assert_equal 'user', manager.context[0][:role]
    assert_equal 'Hello', manager.context[0][:content]
    assert_equal 'assistant', manager.context[1][:role]
    assert_equal 'Hi there!', manager.context[1][:content]
  end

  def test_get_context_without_system_prompt
    manager = AIA::ContextManager.new
    manager.add_to_context(role: 'user', content: 'Hello')
    
    context = manager.get_context
    
    assert_equal 1, context.size
    assert_equal 'user', context.first[:role]
    assert_equal 'Hello', context.first[:content]
  end

  def test_get_context_with_system_prompt_when_none_exists
    manager = AIA::ContextManager.new
    manager.add_to_context(role: 'user', content: 'Hello')
    
    context = manager.get_context(system_prompt: 'You are helpful')
    
    assert_equal 2, context.size
    assert_equal 'system', context.first[:role]
    assert_equal 'You are helpful', context.first[:content]
    assert_equal 'user', context.last[:role]
    assert_equal 'Hello', context.last[:content]
  end

  def test_get_context_with_system_prompt_when_one_already_exists
    manager = AIA::ContextManager.new(system_prompt: 'Original system prompt')
    manager.add_to_context(role: 'user', content: 'Hello')
    
    context = manager.get_context(system_prompt: 'New system prompt')
    
    # Should replace the existing system prompt
    assert_equal 2, context.size
    assert_equal 'system', context.first[:role]
    assert_equal 'New system prompt', context.first[:content]
    assert_equal 'user', context.last[:role]
    assert_equal 'Hello', context.last[:content]
  end

  def test_get_context_with_empty_system_prompt
    manager = AIA::ContextManager.new
    manager.add_to_context(role: 'user', content: 'Hello')
    
    context = manager.get_context(system_prompt: '  ')
    
    # Should not add empty system prompt
    assert_equal 1, context.size
    assert_equal 'user', context.first[:role]
  end

  def test_clear_context_keep_system_prompt_true
    manager = AIA::ContextManager.new(system_prompt: 'System prompt')
    manager.add_to_context(role: 'user', content: 'Hello')
    manager.add_to_context(role: 'assistant', content: 'Hi!')
    
    manager.clear_context(keep_system_prompt: true)
    
    assert_equal 1, manager.context.size
    assert_equal 'system', manager.context.first[:role]
    assert_equal 'System prompt', manager.context.first[:content]
  end

  def test_clear_context_keep_system_prompt_false
    manager = AIA::ContextManager.new(system_prompt: 'System prompt')
    manager.add_to_context(role: 'user', content: 'Hello')
    manager.add_to_context(role: 'assistant', content: 'Hi!')
    
    manager.clear_context(keep_system_prompt: false)
    
    assert_empty manager.context
  end

  def test_clear_context_when_no_system_prompt_exists
    manager = AIA::ContextManager.new
    manager.add_to_context(role: 'user', content: 'Hello')
    manager.add_to_context(role: 'assistant', content: 'Hi!')
    
    manager.clear_context(keep_system_prompt: true)
    
    assert_empty manager.context
  end

  def test_clear_context_calls_client_clear_context
    mock_client = mock('client')
    mock_client.expects(:clear_context)
    mock_client.stubs(:respond_to?).with(:clear_context).returns(true)
    
    AIA.config.client = mock_client
    
    manager = AIA::ContextManager.new
    manager.clear_context
  end

  def test_clear_context_calls_llm_clear_context
    mock_llm = mock('llm')
    mock_llm.expects(:clear_context)
    mock_llm.stubs(:respond_to?).with(:clear_context).returns(true)
    
    AIA.config.llm = mock_llm
    AIA.config.stubs(:respond_to?).with(:llm).returns(true)
    
    manager = AIA::ContextManager.new
    manager.clear_context
  end

  def test_clear_context_calls_ruby_llm_clear_history
    mock_chat = mock('chat')
    mock_chat.expects(:clear_history)
    mock_chat.stubs(:respond_to?).with(:clear_history).returns(true)
    
    # Mock the RubyLLM constant and its methods
    stub_const('RubyLLM', mock('RubyLLM'))
    RubyLLM.stubs(:respond_to?).with(:chat).returns(true)
    RubyLLM.stubs(:chat).returns(mock_chat)
    
    manager = AIA::ContextManager.new
    manager.clear_context
  end

  def test_clear_context_handles_errors_gracefully
    mock_client = mock('client')
    mock_client.stubs(:respond_to?).with(:clear_context).returns(true)
    mock_client.stubs(:clear_context).raises(StandardError.new('Client error'))
    
    AIA.config.client = mock_client
    
    # Should capture the error message
    STDERR.expects(:puts).with('ERROR: context_manager clear_context error Client error')
    
    manager = AIA::ContextManager.new
    manager.clear_context
  end

  def test_add_system_prompt_replaces_existing
    manager = AIA::ContextManager.new
    
    # Manually call the private method using send
    manager.send(:add_system_prompt, 'First prompt')
    manager.add_to_context(role: 'user', content: 'Hello')
    manager.send(:add_system_prompt, 'Second prompt')
    
    assert_equal 2, manager.context.size
    assert_equal 'system', manager.context.first[:role]
    assert_equal 'Second prompt', manager.context.first[:content]
    assert_equal 'user', manager.context.last[:role]
    assert_equal 'Hello', manager.context.last[:content]
  end

  def test_add_system_prompt_when_no_existing_system_prompt
    manager = AIA::ContextManager.new
    manager.add_to_context(role: 'user', content: 'Hello')
    
    manager.send(:add_system_prompt, 'New system prompt')
    
    assert_equal 2, manager.context.size
    assert_equal 'system', manager.context.first[:role]
    assert_equal 'New system prompt', manager.context.first[:content]
    assert_equal 'user', manager.context.last[:role]
    assert_equal 'Hello', manager.context.last[:content]
  end

  private

  def stub_const(const_name, value)
    # Simple constant stubbing for testing
    unless Object.const_defined?(const_name)
      Object.const_set(const_name, value)
      # Note: In a real test suite, you'd want to clean this up in teardown
    end
  end
end