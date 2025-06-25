require_relative '../test_helper'
require 'ostruct'
require 'stringio'
require_relative '../../lib/aia'

class DirectiveProcessorTest < Minitest::Test
  def setup
    @directive_processor = AIA::DirectiveProcessor.new
    @mock_context_manager = mock('context_manager')
  end

  def test_directive_detection_shell
    assert @directive_processor.directive?('//shell echo "Hello"')
    refute @directive_processor.directive?('Just a normal text')
  end

  def test_directive_detection_help
    assert @directive_processor.directive?('//help')
    refute @directive_processor.directive?('help')
  end

  def test_config_directive_detection
    assert @directive_processor.directive?('//config key=value')
  end

  def test_help_directive_detection
    assert @directive_processor.directive?('//help')
  end

  def test_clear_directive_detection
    assert @directive_processor.directive?('//clear')
  end

  def test_non_directive_text
    refute @directive_processor.directive?('This is just regular text')
    refute @directive_processor.directive?('/ single slash is not a directive')
  end

  def test_process_help_directive
    # Capture stdout since help directive prints to stdout and returns empty string
    captured_output = StringIO.new
    original_stdout = $stdout
    $stdout = captured_output
    
    result = @directive_processor.process('//help', @mock_context_manager)
    
    $stdout = original_stdout
    output = captured_output.string
    
    assert_equal '', result
    assert_match /Available Directives/, output
  end

  def test_process_clear_directive
    @mock_context_manager.expects(:clear_context)
    
    result = @directive_processor.process('//clear', @mock_context_manager)
    assert_equal '', result
  end

  def test_process_clear_directive_without_context_manager
    result = @directive_processor.process('//clear', nil)
    assert_match /Error: Context manager not available/, result
  end

  def test_process_non_directive
    input = "This is not a directive"
    result = @directive_processor.process(input, @mock_context_manager)
    assert_equal input, result
  end

  def test_process_unknown_directive
    result = @directive_processor.process('//unknown_directive', @mock_context_manager)
    assert_match /Error: Unknown directive/, result
  end
end