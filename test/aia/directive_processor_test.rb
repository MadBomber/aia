require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class DirectiveProcessorTest < Minitest::Test
  def setup
    # Mock AIA module methods to prevent actual operations
    AIA.stubs(:config).returns(OpenStruct.new(
      model: 'test-model',
      temperature: 0.7,
      max_tokens: 2048,
      chat: false,
      tools: [],
      context_files: []
    ))

    # PM::Directive.register_all is called at load time, registering
    # all AIA directive subclasses.  Ensure directives are available.
    PM.reset_directives!

    @processor = AIA::DirectiveProcessor.new
  end

  def test_initialization
    refute_nil @processor
    assert_instance_of AIA::DirectiveProcessor, @processor
  end

  def test_directive_prefix_constant
    assert_equal '/', AIA::DirectiveProcessor::DIRECTIVE_PREFIX
  end

  def test_directive_with_no_directives
    processor = AIA::DirectiveProcessor.new
    assert processor.respond_to?(:directive?)
    assert processor.respond_to?(:process)
  end

  def test_paste_directive
    processor = AIA::DirectiveProcessor.new

    require 'clipboard'
    Clipboard.stubs(:paste).returns("Test clipboard content")

    result = processor.process("/paste", nil)
    assert_equal "Test clipboard content", result

    result = processor.process("/clipboard", nil)
    assert_equal "Test clipboard content", result
  end

  def test_paste_directive_with_error
    processor = AIA::DirectiveProcessor.new

    require 'clipboard'
    Clipboard.stubs(:paste).raises(StandardError.new("Clipboard access failed"))

    result = processor.process("/paste", nil)
    assert_match(/Error: Unable to paste from clipboard/, result)
  end

  def test_directive_detection
    processor = AIA::DirectiveProcessor.new

    assert processor.directive?("/paste")
    assert processor.directive?("/clipboard")

    refute processor.directive?("paste")
    refute processor.directive?("not a directive")
  end

  def test_directive_detection_uses_pm_directives
    processor = AIA::DirectiveProcessor.new

    # config is registered via register_test_directives
    assert processor.directive?("/config")

    # unregistered names return false
    refute processor.directive?("/nonexistent_directive_xyz")
  end

  def test_file_paths_not_treated_as_directives
    processor = AIA::DirectiveProcessor.new

    refute processor.directive?("/Users/dewayne/file.txt")
    refute processor.directive?("/etc/hosts")
    refute processor.directive?("/tmp/something")
    refute processor.directive?("/usr/local/bin/ruby")
  end

  def test_process_dispatches_through_pm_directives
    processor = AIA::DirectiveProcessor.new

    # The real :config directive returns "" after setting a value
    result = processor.process("/config model gpt-4", nil)
    assert_equal "", result
  end

end
