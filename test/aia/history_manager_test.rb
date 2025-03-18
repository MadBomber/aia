require 'minitest/autorun'
require 'ostruct'
require 'fileutils'
require_relative '../../lib/aia/history_manager'

class HistoryManagerTest < Minitest::Test
  def setup
    @config = OpenStruct.new
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

  def test_get_variable_history
    prompt_id = 'test_prompt'
    variable = 'test_variable'
    value = 'test_value'

    history = @history_manager.get_variable_history(prompt_id, variable, value)
    assert_includes history, value
  end

  def teardown
    # Clean up any files created during tests
    FileUtils.rm_f(@history_manager.instance_variable_get(:@variable_history_file))
  end
end
