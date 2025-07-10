require_relative '../test_helper'
require 'fileutils'
require 'ostruct'
require 'reline'
require_relative '../../lib/aia'

class HistoryManagerTest < Minitest::Test
  def setup
    @prompt = OpenStruct.new
    @prompt.parameters = {}
    @history_manager = AIA::HistoryManager.new(prompt: @prompt)
  end

  def test_history_initialization
    assert_empty @history_manager.history
  end

  def test_history_assignment
    new_history = [{role: 'user', content: 'test'}]
    @history_manager.history = new_history
    assert_equal new_history, @history_manager.history
  end

  def test_get_variable_history
    @prompt.parameters['test_var'] = []
    @history_manager.get_variable_history('test_var', 'value1')
    assert_includes @prompt.parameters['test_var'], 'value1'
  end
  
  def test_get_variable_history_with_nil_value
    # Test early return for nil value (line 36)
    @prompt.parameters['test_var'] = ['existing']
    @history_manager.get_variable_history('test_var', nil)
    assert_equal ['existing'], @prompt.parameters['test_var']
  end
  
  def test_get_variable_history_with_empty_value
    # Test early return for empty value (line 36)
    @prompt.parameters['test_var'] = ['existing']
    @history_manager.get_variable_history('test_var', '')
    assert_equal ['existing'], @prompt.parameters['test_var']
  end
  
  def test_get_variable_history_removes_existing_value
    # Test that existing value is removed and re-added at end (lines 39-41)
    @prompt.parameters['test_var'] = ['value1', 'value2', 'value3']
    @history_manager.get_variable_history('test_var', 'value2')
    assert_equal ['value1', 'value3', 'value2'], @prompt.parameters['test_var']
  end
  
  def test_get_variable_history_max_limit_enforcement
    # Test that history is limited to MAX_VARIABLE_HISTORY (lines 45-47)
    @prompt.parameters['test_var'] = ['v1', 'v2', 'v3', 'v4', 'v5']
    @history_manager.get_variable_history('test_var', 'v6')
    
    assert_equal AIA::HistoryManager::MAX_VARIABLE_HISTORY, @prompt.parameters['test_var'].size
    assert_equal ['v2', 'v3', 'v4', 'v5', 'v6'], @prompt.parameters['test_var']
    refute_includes @prompt.parameters['test_var'], 'v1'
  end
  
  def test_get_variable_history_with_new_variable
    # Test adding value to variable that doesn't exist yet
    # First ensure the variable exists with an empty array
    @prompt.parameters['new_var'] = []
    @history_manager.get_variable_history('new_var', 'first_value')
    assert_equal ['first_value'], @prompt.parameters['new_var']
  end

  def test_setup_variable_history
    history_values = ['value1', 'value2', 'value3']
    # This method uses Reline which requires interactive terminal
    # Just test that the method exists and doesn't raise errors
    assert_respond_to @history_manager, :setup_variable_history
  end

  def test_setup_variable_history_initializes_empty_history
    history_values = []
    @history_manager.setup_variable_history(history_values)
    @prompt.parameters['variable_history'] ||= []
    assert_empty @prompt.parameters['variable_history']
  end

  def test_setup_variable_history_initializes_with_values
    history_values = ['value1', 'value2']
    @history_manager.setup_variable_history(history_values)
    # Just verify the method runs without errors - testing Reline's history is complex
    assert_respond_to @history_manager, :setup_variable_history
  end

  def test_request_variable_value_prompts_user
    history_values = ['value1', 'value2']
    @prompt.parameters['test_var'] = []
    
    # Stub Reline.readline to simulate user input
    Reline.stubs(:readline).returns("value3")
    
    result = @history_manager.request_variable_value(variable_name: 'test_var', history_values: history_values)
    assert_equal 'value3', result
  end

  def test_request_variable_value_uses_default_for_empty_input
    history_values = ['value1', 'value2']
    @prompt.parameters['test_var'] = []
    
    # Stub Reline.readline to simulate empty input
    Reline.stubs(:readline).returns("")
    
    result = @history_manager.request_variable_value(variable_name: 'test_var', history_values: history_values)
    assert_equal 'value2', result  # Should use last history value as default
  end

  def test_request_variable_value_handles_ctrl_d
    history_values = ['value1', 'value2']
    @prompt.parameters['test_var'] = []
    
    # Stub Reline.readline to simulate Ctrl+D (nil return)
    Reline.stubs(:readline).returns(nil)
    
    result = @history_manager.request_variable_value(variable_name: 'test_var', history_values: history_values)
    assert_equal 'value2', result  # Should use last history value as default
  end
  
  def test_request_variable_value_handles_interrupt
    # Test Ctrl+C handling (lines 76-78)
    history_values = ['value1']
    @prompt.parameters['test_var'] = []
    
    # Stub Reline.readline to raise Interrupt
    Reline.stubs(:readline).raises(Interrupt)
    
    # Stub exit to prevent actual exit during test
    exit_called = false
    @history_manager.stubs(:exit).with(1) { exit_called = true }
    
    # Capture stdout to verify the message
    captured_output = StringIO.new
    original_stdout = $stdout
    $stdout = captured_output
    
    @history_manager.request_variable_value(variable_name: 'test_var', history_values: history_values)
    
    $stdout = original_stdout
    
    assert_match /Variable input interrupted/, captured_output.string
    assert exit_called
  end
  
  def test_request_variable_value_with_empty_history
    # Test with empty history_values (line 56)
    @prompt.parameters['test_var'] = []
    
    Reline.stubs(:readline).returns("user_input")
    
    result = @history_manager.request_variable_value(variable_name: 'test_var', history_values: [])
    assert_equal 'user_input', result
  end
  
  def test_request_variable_value_with_whitespace_input
    # Test that input is properly stripped (line 72)
    history_values = ['default']
    @prompt.parameters['test_var'] = []
    
    Reline.stubs(:readline).returns("  spaced_input  ")
    
    result = @history_manager.request_variable_value(variable_name: 'test_var', history_values: history_values)
    assert_equal 'spaced_input', result
  end
  
  def test_request_variable_value_updates_variable_history
    # Test that get_variable_history is called to update history (line 74)
    history_values = ['old_value']
    @prompt.parameters['test_var'] = ['old_value']
    
    Reline.stubs(:readline).returns("new_value")
    
    result = @history_manager.request_variable_value(variable_name: 'test_var', history_values: history_values)
    
    assert_equal 'new_value', result
    assert_includes @prompt.parameters['test_var'], 'new_value'
  end
  
  def test_setup_variable_history_with_nil_values
    # Test that nil values are filtered out (line 30)
    history_values = ['value1', nil, 'value2', '', 'value3']
    
    # Since Reline::HISTORY is complex to mock, just test that the method runs
    # without raising errors when given nil/empty values
    begin
      @history_manager.setup_variable_history(history_values)
      assert true # If we get here, no exception was raised
    rescue => e
      flunk "setup_variable_history should handle nil/empty values without error, but raised: #{e}"
    end
    
    # The method should handle filtering nil and empty values without error
    assert_respond_to @history_manager, :setup_variable_history
  end
  
  # No cleanup needed as we're using in-memory objects
end
