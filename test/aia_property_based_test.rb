require_relative 'test_helper'
require 'ostruct'
require_relative '../lib/aia'

class AIAPropertyBasedTest < Minitest::Test
  def setup
    # Mock AIA module methods to prevent actual operations
    AIA.stubs(:bad_file?).returns(false)
    AIA.stubs(:good_file?).returns(true)

    # Mock AIA.config
    @mock_config = OpenStruct.new(
      model: 'test-model',
      temperature: 0.7,
      max_tokens: 2048,
      chat: false,
      tools: []
    )
    AIA.stubs(:config).returns(@mock_config)
  end

  def teardown
    # Call super to ensure Mocha cleanup runs properly
    super
  end

  def test_basic_configuration_parsing
    # Test that config can be created and accessed
    assert_equal 'test-model', AIA.config.model
    assert_equal 0.7, AIA.config.temperature
    assert_equal 2048, AIA.config.max_tokens
    assert_equal false, AIA.config.chat
    assert_equal [], AIA.config.tools
  end

  def test_boolean_flag_normalization
    # Test basic boolean normalization
    config = OpenStruct.new(test_flag: 'true')
    AIA::Config.normalize_boolean_flag(config, :test_flag)
    assert_equal true, config.test_flag

    config = OpenStruct.new(test_flag: nil)
    AIA::Config.normalize_boolean_flag(config, :test_flag)
    assert_equal false, config.test_flag
  end

  def test_environment_variable_handling
    # Test basic environment variable parsing
    ENV['AIA_MODEL'] = 'test-env-model'
    
    default_config = OpenStruct.new(model: 'default')
    cli_config = OpenStruct.new
    
    result = AIA::Config.envar_options(default_config, cli_config)
    assert_equal 'test-env-model', result.model
    
    ENV.delete('AIA_MODEL')
  end
end