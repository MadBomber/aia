require_relative '../test_helper'
require 'fileutils'
require 'ostruct'
require_relative '../../lib/aia'

class HistoryManagerTest < Minitest::Test
  def setup
    @config = OpenStruct.new
    @config.prompt_id = 'test_prompt_id'
    @history_manager = AIA::HistoryManager.new(@config)
    @history_manager.clear_history
  end

  def test_add_to_history
    @history_manager.add_to_history('user', 'Hello, AI!')
    assert_equal 1, @history_manager.history.size
    assert_equal 'user', @history_manager.history.first[:role]
    assert_equal 'Hello, AI!', @history_manager.history.first[:content]
  end

  def test_clear_history
    @history_manager.add_to_history('user', 'Hello, AI!')
    @history_manager.clear_history
    assert_empty @history_manager.history
  end

  def test_add_to_history
    @history_manager.add_to_history('user', 'Hello')
    assert_equal 1, @history_manager.history.size
    assert_equal 'user', @history_manager.history.first[:role]
    assert_equal 'Hello', @history_manager.history.first[:content]
  end

  def test_clear_history
    @history_manager.add_to_history('user', 'Hello')
    @history_manager.clear_history
    assert_empty @history_manager.history
  end

  def test_build_conversation_context
    @history_manager.add_to_history('user', 'Hello')
    context = @history_manager.build_conversation_context('How are you?')
    assert_match /User: Hello/, context
    assert_match /User: How are you?/, context
  end

  def test_get_variable_history
    history = @history_manager.get_variable_history('prompt1', 'var1', 'value1')
    assert_includes history, 'value1'
  end

  def teardown
    # Clean up any files created during tests
    FileUtils.rm_f(@history_manager.instance_variable_get(:@variable_history_file))
  end
end
