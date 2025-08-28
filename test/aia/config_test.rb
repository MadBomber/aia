require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class ConfigTest < Minitest::Test
  def setup
    # Basic mocks to prevent actual file operations
    AIA.stubs(:good_file?).returns(true)
    AIA.stubs(:bad_file?).returns(false)
    
    @test_config = OpenStruct.new(
      model: 'test-model',
      temperature: 0.7,
      max_tokens: 2048,
      chat: false,
      tools: [],
      fuzzy: false
    )
  end

  def test_basic_config_creation
    # Test basic config object creation
    assert_instance_of OpenStruct, @test_config
    assert_equal 'test-model', @test_config.model
    assert_equal 0.7, @test_config.temperature
    assert_equal 2048, @test_config.max_tokens
  end

  def test_boolean_flag_normalization
    # Test boolean flag normalization functionality
    config = OpenStruct.new(test_flag: 'true')
    AIA::Config.normalize_boolean_flag(config, :test_flag)
    assert_equal true, config.test_flag

    config = OpenStruct.new(test_flag: nil)
    AIA::Config.normalize_boolean_flag(config, :test_flag)
    assert_equal false, config.test_flag
  end

  def test_environment_variable_parsing
    # Test environment variable processing
    ENV['AIA_MODEL'] = 'env-test-model'
    
    default_config = OpenStruct.new(model: 'default')
    cli_config = OpenStruct.new
    
    result = AIA::Config.envar_options(default_config, cli_config)
    assert_equal 'env-test-model', result.model
    
    ENV.delete('AIA_MODEL')
  end

  def test_config_validation
    # Test basic config validation
    config = OpenStruct.new(model: 'valid-model')
    
    # Basic validation test
    assert_equal 'valid-model', config.model
    assert config.respond_to?(:model)
  end
end