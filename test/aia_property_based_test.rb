# frozen_string_literal: true

require_relative 'test_helper'
require 'ostruct'
require_relative '../lib/aia'

class AIAPropertyBasedTest < Minitest::Test
  def setup
    # Mock AIA module methods to prevent actual operations
    AIA.stubs(:bad_file?).returns(false)
    AIA.stubs(:good_file?).returns(true)

    # Mock AIA.config with nested structure (matching new config layout)
    @mock_config = OpenStruct.new(
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      models: [OpenStruct.new(name: 'test-model')],
      flags: OpenStruct.new(chat: false, debug: false),
      tools: OpenStruct.new(paths: [])
    )
    AIA.stubs(:config).returns(@mock_config)
  end

  def teardown
    # Call super to ensure Mocha cleanup runs properly
    super
  end

  def test_basic_configuration_parsing
    # Test that config can be created and accessed with nested structure
    assert_equal 'test-model', AIA.config.models.first.name
    assert_equal 0.7, AIA.config.llm.temperature
    assert_equal 2048, AIA.config.llm.max_tokens
    assert_equal false, AIA.config.flags.chat
    assert_equal [], AIA.config.tools.paths
  end

  def test_boolean_flag_normalization
    # Test basic boolean normalization using ConfigValidator
    flags_section = OpenStruct.new(test_flag: 'true')
    AIA::ConfigValidator.normalize_boolean_flag(flags_section, :test_flag)
    assert_equal true, flags_section.test_flag

    flags_section = OpenStruct.new(test_flag: nil)
    AIA::ConfigValidator.normalize_boolean_flag(flags_section, :test_flag)
    assert_equal false, flags_section.test_flag
  end

  def test_environment_variable_handling
    # Test that myway_config handles environment variables
    # This is now handled automatically by the myway_config gem
    # We test that our Config class properly loads from defaults
    config = AIA::Config.new
    assert_respond_to config, :llm
    assert_respond_to config, :models
    assert_respond_to config, :flags
  end
end
