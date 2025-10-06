# frozen_string_literal: true
# test/aia/config_model_roles_test.rb
# Tests for ADR-005 v2: Config file and environment variable model_roles support

require_relative '../test_helper'
require 'ostruct'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/extensions/openstruct_merge'
require_relative '../../lib/aia/config/file_loader'
require_relative '../../lib/aia/config/base'
require_relative '../../lib/aia/config/cli_parser'

class ConfigModelRolesTest < Minitest::Test
  def setup
    @original_env = ENV.to_h.dup
    @temp_dir = Dir.mktmpdir('aia_config_test')

    # Create test role files
    @roles_dir = File.join(@temp_dir, 'roles')
    FileUtils.mkdir_p(@roles_dir)
    File.write(File.join(@roles_dir, 'architect.txt'), 'You are an architect')
    File.write(File.join(@roles_dir, 'security.txt'), 'You are a security expert')
    File.write(File.join(@roles_dir, 'performance.txt'), 'You are a performance expert')

    ENV['AIA_PROMPTS_DIR'] = @temp_dir
    ENV['AIA_ROLES_PREFIX'] = 'roles'
  end

  def teardown
    # Clean up temporary directory
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)

    # Restore original environment
    ENV.clear
    @original_env.each { |k, v| ENV[k] = v }
  end

  # Test config file with Array format
  def test_process_model_array_with_roles
    models = [
      { model: 'gpt-4o', role: 'architect' },
      { model: 'claude', role: 'security' },
      { model: 'gemini', role: 'performance' }
    ]

    result = AIA::ConfigModules::FileLoader.process_model_array_with_roles(models)

    assert_equal 3, result.length

    assert_equal 'gpt-4o', result[0][:model]
    assert_equal 'architect', result[0][:role]
    assert_equal 1, result[0][:instance]
    assert_equal 'gpt-4o', result[0][:internal_id]

    assert_equal 'claude', result[1][:model]
    assert_equal 'security', result[1][:role]

    assert_equal 'gemini', result[2][:model]
    assert_equal 'performance', result[2][:role]
  end

  # Test config file with models without roles
  def test_process_model_array_without_roles
    models = [
      { model: 'gpt-4o' },
      { model: 'claude' }
    ]

    result = AIA::ConfigModules::FileLoader.process_model_array_with_roles(models)

    assert_equal 2, result.length
    assert_equal 'gpt-4o', result[0][:model]
    assert_nil result[0][:role]
    assert_equal 'claude', result[1][:model]
    assert_nil result[1][:role]
  end

  # Test config file with duplicate models
  def test_process_model_array_with_duplicates
    models = [
      { model: 'gpt-4o', role: 'optimist' },
      { model: 'gpt-4o', role: 'pessimist' },
      { model: 'gpt-4o', role: 'realist' }
    ]

    result = AIA::ConfigModules::FileLoader.process_model_array_with_roles(models)

    assert_equal 3, result.length

    assert_equal 'gpt-4o', result[0][:internal_id]
    assert_equal 1, result[0][:instance]

    assert_equal 'gpt-4o#2', result[1][:internal_id]
    assert_equal 2, result[1][:instance]

    assert_equal 'gpt-4o#3', result[2][:internal_id]
    assert_equal 3, result[2][:instance]
  end

  # Test environment variable with inline syntax
  def test_env_var_inline_syntax
    ENV['AIA_MODEL'] = 'gpt-4o=architect,claude=security,gemini=performance'

    # Create minimal config for testing
    default_config = OpenStruct.new(model: [])
    cli_config = OpenStruct.new

    result = AIA::ConfigModules::Base.envar_options(default_config, cli_config)

    assert result.model.is_a?(Array)
    assert_equal 3, result.model.length

    assert_equal 'gpt-4o', result.model[0][:model]
    assert_equal 'architect', result.model[0][:role]

    assert_equal 'claude', result.model[1][:model]
    assert_equal 'security', result.model[1][:role]

    assert_equal 'gemini', result.model[2][:model]
    assert_equal 'performance', result.model[2][:role]
  end

  # Test environment variable without inline syntax (backward compatibility)
  def test_env_var_without_inline_syntax
    ENV['AIA_MODEL'] = 'gpt-4o,claude,gemini'

    default_config = OpenStruct.new(model: [])
    cli_config = OpenStruct.new

    result = AIA::ConfigModules::Base.envar_options(default_config, cli_config)

    assert result.model.is_a?(Array)
    assert_equal 3, result.model.length
    assert_equal ['gpt-4o', 'claude', 'gemini'], result.model
  end

  # Test YAML config file with model array
  def test_yaml_config_with_model_array
    config_file = File.join(@temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      model:
        - model: gpt-4o
          role: architect
        - model: claude
          role: security
    YAML

    result = AIA::ConfigModules::FileLoader.cf_options(config_file)

    assert result.model.is_a?(Array)
    assert_equal 2, result.model.length

    assert_equal 'gpt-4o', result.model[0][:model]
    assert_equal 'architect', result.model[0][:role]

    assert_equal 'claude', result.model[1][:model]
    assert_equal 'security', result.model[1][:role]
  end

  # Test empty model array
  def test_empty_model_array
    result = AIA::ConfigModules::FileLoader.process_model_array_with_roles([])
    assert_equal [], result

    result = AIA::ConfigModules::FileLoader.process_model_array_with_roles(nil)
    assert_equal [], result
  end

  # Test string keys in array format (common in YAML)
  def test_model_array_with_string_keys
    models = [
      { 'model' => 'gpt-4o', 'role' => 'architect' },
      { 'model' => 'claude', 'role' => 'security' }
    ]

    result = AIA::ConfigModules::FileLoader.process_model_array_with_roles(models)

    assert_equal 2, result.length
    assert_equal 'gpt-4o', result[0][:model]
    assert_equal 'architect', result[0][:role]
  end
end
