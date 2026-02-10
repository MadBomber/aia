# frozen_string_literal: true

require_relative '../../test_helper'

class ErrorHandlerTest < Minitest::Test
  def setup
    @adapter = AIA::RubyLLMAdapter.allocate
    @adapter.instance_variable_set(:@chats, {})
    @adapter.instance_variable_set(:@models, [])
    @adapter.instance_variable_set(:@contexts, {})
    @adapter.instance_variable_set(:@tools, [])
    @adapter.instance_variable_set(:@model_specs, [])
  end

  def teardown
    super
  end

  # --- handle_tool_crash ---

  def test_handle_tool_crash_returns_error_message
    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(false)

    exception = StandardError.new('something broke')
    exception.set_backtrace(['line1.rb:10', 'line2.rb:20', 'line3.rb:30'])

    result = capture_io do
      @result = @adapter.handle_tool_crash(mock_chat, exception)
    end

    assert_includes @result, 'Tool error'
    assert_includes @result, 'something broke'
    assert_includes @result, 'StandardError'
  end

  def test_handle_tool_crash_outputs_backtrace
    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(false)

    exception = RuntimeError.new('crash')
    exception.set_backtrace(['file_a.rb:1', 'file_b.rb:2', 'file_c.rb:3', 'file_d.rb:4', 'file_e.rb:5', 'file_f.rb:6'])

    # warn is called 3 times: error_msg, backtrace (first 5 lines), blank line
    warn_calls = []
    @adapter.stubs(:warn).with { |msg| warn_calls << msg; true }

    @adapter.handle_tool_crash(mock_chat, exception)

    backtrace_output = warn_calls.join("\n")
    assert_match(/file_a\.rb:1/, backtrace_output)
    assert_match(/file_e\.rb:5/, backtrace_output)
    # Should NOT show 6th line
    refute_match(/file_f\.rb:6/, backtrace_output)
  end

  def test_handle_tool_crash_without_backtrace
    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(false)

    exception = StandardError.new('no trace')
    # No set_backtrace call, so backtrace is nil

    # Should not raise
    capture_io do
      result = @adapter.handle_tool_crash(mock_chat, exception)
      assert_includes result, 'no trace'
    end
  end

  def test_handle_tool_crash_calls_repair
    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(true)
    mock_chat.stubs(:messages).returns([])

    exception = StandardError.new('error')
    exception.set_backtrace([])

    capture_io do
      @adapter.handle_tool_crash(mock_chat, exception)
    end
    # No assertion needed - just verifying no exception raised
  end

  # --- repair_incomplete_tool_calls ---

  def test_repair_skips_when_no_messages_method
    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(false)

    # Should not raise
    @adapter.repair_incomplete_tool_calls(mock_chat, 'error msg')
  end

  def test_repair_skips_when_messages_empty
    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(true)
    mock_chat.stubs(:messages).returns([])

    # Should not raise
    @adapter.repair_incomplete_tool_calls(mock_chat, 'error msg')
  end

  def test_repair_skips_when_no_tool_calls
    mock_msg = mock('msg')
    mock_msg.stubs(:role).returns(:assistant)
    mock_msg.stubs(:respond_to?).with(:tool_calls).returns(true)
    mock_msg.stubs(:tool_calls).returns(nil)

    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(true)
    mock_chat.stubs(:messages).returns([mock_msg])

    # Should not raise
    @adapter.repair_incomplete_tool_calls(mock_chat, 'error msg')
  end

  def test_repair_adds_synthetic_tool_results
    # Create assistant message with tool calls
    tool_calls = { 'call_123' => { name: 'calculator', arguments: {} } }

    mock_assistant_msg = mock('assistant_msg')
    mock_assistant_msg.stubs(:role).returns(:assistant)
    mock_assistant_msg.stubs(:respond_to?).with(:tool_calls).returns(true)
    mock_assistant_msg.stubs(:tool_calls).returns(tool_calls)

    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(true)
    mock_chat.stubs(:messages).returns([mock_assistant_msg])

    # Expect a synthetic tool result to be added
    mock_chat.expects(:add_message).with(
      role: :tool,
      content: 'Error: tool failed',
      tool_call_id: 'call_123'
    )

    @adapter.repair_incomplete_tool_calls(mock_chat, 'tool failed')
  end

  def test_repair_skips_existing_tool_results
    tool_calls = { 'call_123' => { name: 'calculator', arguments: {} } }

    mock_assistant_msg = mock('assistant_msg')
    mock_assistant_msg.stubs(:role).returns(:assistant)
    mock_assistant_msg.stubs(:respond_to?).with(:tool_calls).returns(true)
    mock_assistant_msg.stubs(:tool_calls).returns(tool_calls)

    mock_tool_msg = mock('tool_msg')
    mock_tool_msg.stubs(:role).returns(:tool)
    mock_tool_msg.stubs(:tool_call_id).returns('call_123')

    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(true)
    mock_chat.stubs(:messages).returns([mock_assistant_msg, mock_tool_msg])

    # Should NOT add a message because tool result already exists
    mock_chat.expects(:add_message).never

    @adapter.repair_incomplete_tool_calls(mock_chat, 'error')
  end

  def test_repair_handles_multiple_tool_calls
    tool_calls = {
      'call_1' => { name: 'tool_a', arguments: {} },
      'call_2' => { name: 'tool_b', arguments: {} }
    }

    mock_assistant_msg = mock('assistant_msg')
    mock_assistant_msg.stubs(:role).returns(:assistant)
    mock_assistant_msg.stubs(:respond_to?).with(:tool_calls).returns(true)
    mock_assistant_msg.stubs(:tool_calls).returns(tool_calls)

    # Only call_1 has a result
    mock_tool_msg = mock('tool_msg')
    mock_tool_msg.stubs(:role).returns(:tool)
    mock_tool_msg.stubs(:tool_call_id).returns('call_1')

    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(true)
    mock_chat.stubs(:messages).returns([mock_assistant_msg, mock_tool_msg])

    # Should add synthetic result only for call_2
    mock_chat.expects(:add_message).with(
      role: :tool,
      content: 'Error: error msg',
      tool_call_id: 'call_2'
    )

    @adapter.repair_incomplete_tool_calls(mock_chat, 'error msg')
  end

  def test_repair_does_not_cascade_failures
    mock_chat = mock('chat')
    mock_chat.stubs(:respond_to?).with(:messages).returns(true)
    mock_chat.stubs(:messages).raises(StandardError, 'unexpected')

    # Should not raise - errors are caught internally
    @adapter.repair_incomplete_tool_calls(mock_chat, 'error')
  end
end
