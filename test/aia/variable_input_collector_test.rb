require_relative '../test_helper'
require 'ostruct'
require 'reline'
require_relative '../../lib/aia'

class VariableInputCollectorTest < Minitest::Test
  def setup
    @collector = AIA::VariableInputCollector.new
  end

  def test_initialization
    assert_instance_of AIA::VariableInputCollector, @collector
  end

  def test_history_manager_alias_points_to_same_class
    assert_equal AIA::VariableInputCollector, AIA::HistoryManager
  end

  def test_request_variable_value_prompts_user
    Reline.stubs(:readline).returns("user_input")
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    result = @collector.request_variable_value(variable_name: 'name', default_value: 'default')
    assert_equal 'user_input', result
  end

  def test_request_variable_value_uses_default_for_empty_input
    Reline.stubs(:readline).returns("")
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    result = @collector.request_variable_value(variable_name: 'name', default_value: 'fallback')
    assert_equal 'fallback', result
  end

  def test_request_variable_value_uses_default_for_ctrl_d
    Reline.stubs(:readline).returns(nil)
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    result = @collector.request_variable_value(variable_name: 'name', default_value: 'fallback')
    assert_equal 'fallback', result
  end

  def test_request_variable_value_raises_on_ctrl_d_when_required
    Reline.stubs(:readline).returns(nil)
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    err = assert_raises(AIA::Error) do
      @collector.request_variable_value(variable_name: 'name', default_value: nil)
    end
    assert_match(/name/, err.message)
  end

  def test_request_variable_value_raises_on_empty_when_required
    Reline.stubs(:readline).returns("")
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    err = assert_raises(AIA::Error) do
      @collector.request_variable_value(variable_name: 'name', default_value: nil)
    end
    assert_match(/name/, err.message)
  end

  def test_request_variable_value_raises_on_interrupt
    Reline.stubs(:readline).raises(Interrupt)
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    assert_raises(AIA::Error) do
      @collector.request_variable_value(variable_name: 'name', default_value: 'default')
    end
  end

  def test_request_variable_value_strips_whitespace
    Reline.stubs(:readline).returns("  spaced_input  ")
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    result = @collector.request_variable_value(variable_name: 'name', default_value: 'default')
    assert_equal 'spaced_input', result
  end

  def test_request_variable_value_shows_default_in_prompt
    question_asked = nil
    Reline.stubs(:readline).with { |q, _| question_asked = q; true }.returns("val")
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    @collector.request_variable_value(variable_name: 'color', default_value: 'blue')
    assert_match(/color/, question_asked)
    assert_match(/blue/, question_asked)
  end

  def test_request_variable_value_shows_required_when_no_default
    question_asked = nil
    Reline.stubs(:readline).with { |q, _| question_asked = q; true }.returns("val")
    Reline.stubs(:line_editor).returns(OpenStruct.new(prompt_proc: nil, :prompt_proc= => nil))

    @collector.request_variable_value(variable_name: 'color', default_value: nil)
    assert_match(/color/, question_asked)
    assert_match(/required/, question_asked)
  end
end
