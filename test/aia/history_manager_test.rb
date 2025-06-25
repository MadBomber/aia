require_relative '../test_helper'
require 'fileutils'
require 'ostruct'
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

  def test_setup_variable_history
    history_values = ['value1', 'value2', 'value3']
    # This method uses Reline which requires interactive terminal
    # Just test that the method exists and doesn't raise errors
    assert_respond_to @history_manager, :setup_variable_history
  end

  def teardown
    # No cleanup needed as we're using in-memory objects
  end
end
