require_relative 'test_helper'
require_relative '../lib/aia'

class AIAMockingTest < Minitest::Test
  def setup
    # Basic mocking setup
    AIA.stubs(:config).returns(OpenStruct.new(
      model: 'test-model',
      tools: [],
      context_files: []
    ))
  end

  def teardown
    # Call super to ensure Mocha cleanup runs properly
    super
  end

  def test_basic_mocking_functionality
    # Simple test that mocking works
    assert_equal 'test-model', AIA.config.model
    assert_equal [], AIA.config.tools
    assert_equal [], AIA.config.context_files
  end

  def test_file_operations_can_be_mocked
    # Basic file operations test
    File.stubs(:exist?).returns(true)
    assert File.exist?('any_file.txt')
  end

  def test_system_operations_can_be_mocked
    # Basic system operations test
    system_result = true
    self.stubs(:system).returns(system_result)
    result = system('echo test')
    assert_equal true, result
  end
end