require 'minitest/autorun'
require 'ostruct'
require_relative '../../lib/aia/directive_processor'

class DirectiveProcessorTest < Minitest::Test
  def setup
    @config = OpenStruct.new
    @directive_processor = AIA::DirectiveProcessor.new(@config)
  end

  def test_directive_detection
    assert @directive_processor.directive?('//shell echo "Hello"')
    refute @directive_processor.directive?('Just a normal text')
  end

  def test_config_directive_detection
    assert @directive_processor.config_directive?('//config key=value')
    refute @directive_processor.config_directive?('//shell echo "Hello"')
  end

  def test_help_directive_detection
    assert @directive_processor.help_directive?('//help')
    refute @directive_processor.help_directive?('//shell echo "Hello"')
  end

  def test_clear_directive_detection
    assert @directive_processor.clear_directive?('//clear')
    refute @directive_processor.clear_directive?('//shell echo "Hello"')
  end

  def test_exclude_from_chat_context
    assert @directive_processor.exclude_from_chat_context?('//config key=value')
    refute @directive_processor.exclude_from_chat_context?('//shell echo "Hello"')
  end

  def test_process_help_directive
    result = @directive_processor.process('//help')
    assert_includes result[:result], 'Available Directives:'
  end

  def test_process_clear_directive
    history = ['Some history']
    result = @directive_processor.process('//clear', history)
    assert_empty result[:modified_history]
    assert_equal "Conversation context has been cleared. The AI will have no memory of our previous conversation.", result[:result]
  end
end
