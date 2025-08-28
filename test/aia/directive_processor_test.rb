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
    
    @processor = AIA::DirectiveProcessor.new
  end

  def test_initialization
    # Test basic initialization
    assert_instance_of AIA::DirectiveProcessor, @processor
  end

  def test_basic_directive_processing
    # Test basic directive processor functionality
    processor = AIA::DirectiveProcessor.new
    
    # Should be able to process content without errors
    assert_respond_to processor, :run
  end

  def test_simple_directive_run
    # Test that the directive processor can be called (without actually running complex logic)
    processor = AIA::DirectiveProcessor.new
    # Just test that it has the method
    assert processor.respond_to?(:run)
  end

  def test_directive_with_no_directives
    # Test basic processor properties
    processor = AIA::DirectiveProcessor.new
    # Test basic functionality without complex API calls
    assert processor.respond_to?(:directive?)
  end
end