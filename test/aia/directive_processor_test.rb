require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class DirectiveProcessorTest < Minitest::Test
  def setup
    @config = OpenStruct.new
    @config.prompt_id = 'test_prompt_id'
    @directive_processor = AIA::DirectiveProcessor.new(@config)
  end

  def test_directive_detection
    assert @directive_processor.directive?('//shell echo "Hello"')
    refute @directive_processor.directive?('Just a normal text')
  end

  def test_directive_detection
    assert @directive_processor.directive?('//help')
    refute @directive_processor.directive?('help')
  end

  def test_config_directive_detection
    assert @directive_processor.directive?('//config key=value', 'config')
  end

  def test_help_directive_detection
    assert @directive_processor.directive?('//help', 'help')
  end

  def test_clear_directive_detection
    assert @directive_processor.directive?('//clear', 'clear')
  end

  def test_exclude_from_chat_context
    assert @directive_processor.exclude_from_chat_context?('//config key=value')
  end

  def test_process_help_directive
    result = @directive_processor.process('//help')
    assert_match /Available Directives:/, result[:result]
  end

  def test_process_clear_directive
    history = [{ role: 'user', content: 'Hello' }]
    result = @directive_processor.process('//clear', history)
    assert_empty result[:modified_history]
  end
end
