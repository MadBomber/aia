# test/aia/role_parsing_test.rb

require_relative '../test_helper'
require 'ostruct'
require 'fileutils'
require 'tmpdir'
require_relative '../../lib/aia/config/cli_parser'

class RoleParsingTest < Minitest::Test
  def setup
    # Create a temporary directory for test role files
    @temp_dir = Dir.mktmpdir('aia_role_test')
    @roles_dir = File.join(@temp_dir, 'roles')
    FileUtils.mkdir_p(@roles_dir)

    # Create test role files
    File.write(File.join(@roles_dir, 'architect.txt'), 'You are an architect')
    File.write(File.join(@roles_dir, 'security.txt'), 'You are a security expert')
    File.write(File.join(@roles_dir, 'performance.txt'), 'You are a performance expert')
    File.write(File.join(@roles_dir, 'optimist.txt'), 'You are an optimist')
    File.write(File.join(@roles_dir, 'pessimist.txt'), 'You are a pessimist')
    File.write(File.join(@roles_dir, 'realist.txt'), 'You are a realist')

    # Create nested role
    nested_dir = File.join(@roles_dir, 'specialized')
    FileUtils.mkdir_p(nested_dir)
    File.write(File.join(nested_dir, 'senior_architect.txt'), 'You are a senior architect')

    # Set environment variables for testing (using nested config format with double underscore)
    ENV['AIA_PROMPTS__DIR'] = @temp_dir
    ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'
  end

  def teardown
    # Clean up temporary directory
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end

  # Test basic model parsing without roles
  def test_parse_single_model_without_role
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o')

    assert_equal 1, result.length
    assert_equal 'gpt-4o', result[0][:name]
    assert_nil result[0][:role]
    assert_equal 1, result[0][:instance]
    assert_equal 'gpt-4o', result[0][:internal_id]
  end

  # Test multiple models without roles
  def test_parse_multiple_models_without_roles
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o,claude,gemini')

    assert_equal 3, result.length
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'claude', result[1][:name]
    assert_equal 'gemini', result[2][:name]
    result.each { |spec| assert_nil spec[:role] }
  end

  # Test single model with role
  def test_parse_single_model_with_role
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=architect')

    assert_equal 1, result.length
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'architect', result[0][:role]
    assert_equal 1, result[0][:instance]
    assert_equal 'gpt-4o', result[0][:internal_id]
  end

  # Test multiple models with different roles
  def test_parse_multiple_models_with_roles
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=architect,claude=security,gemini=performance')

    assert_equal 3, result.length

    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'architect', result[0][:role]

    assert_equal 'claude', result[1][:name]
    assert_equal 'security', result[1][:role]

    assert_equal 'gemini', result[2][:name]
    assert_equal 'performance', result[2][:role]
  end

  # Test mixed: some models with roles, some without
  def test_parse_mixed_models_with_and_without_roles
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=architect,claude,gemini=performance')

    assert_equal 3, result.length

    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'architect', result[0][:role]

    assert_equal 'claude', result[1][:name]
    assert_nil result[1][:role]

    assert_equal 'gemini', result[2][:name]
    assert_equal 'performance', result[2][:role]
  end

  # Test duplicate models with different roles
  def test_parse_duplicate_models_with_different_roles
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=optimist,gpt-4o=pessimist,gpt-4o=realist')

    assert_equal 3, result.length

    # First instance
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'optimist', result[0][:role]
    assert_equal 1, result[0][:instance]
    assert_equal 'gpt-4o', result[0][:internal_id]

    # Second instance
    assert_equal 'gpt-4o', result[1][:name]
    assert_equal 'pessimist', result[1][:role]
    assert_equal 2, result[1][:instance]
    assert_equal 'gpt-4o#2', result[1][:internal_id]

    # Third instance
    assert_equal 'gpt-4o', result[2][:name]
    assert_equal 'realist', result[2][:role]
    assert_equal 3, result[2][:instance]
    assert_equal 'gpt-4o#3', result[2][:internal_id]
  end

  # Test nested role path
  def test_parse_nested_role_path
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=specialized/senior_architect')

    assert_equal 1, result.length
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'specialized/senior_architect', result[0][:role]
  end

  # Test provider syntax with role
  def test_parse_provider_syntax_with_role
    result = AIA::CLIParser.send(:parse_models_with_roles, 'ollama/llama2=architect,lms/gpt-4o=security')

    assert_equal 2, result.length

    assert_equal 'ollama/llama2', result[0][:name]
    assert_equal 'architect', result[0][:role]

    assert_equal 'lms/gpt-4o', result[1][:name]
    assert_equal 'security', result[1][:role]
  end

  # Test whitespace handling
  def test_parse_with_whitespace
    result = AIA::CLIParser.send(:parse_models_with_roles, '  gpt-4o = architect , claude = security  ')

    assert_equal 2, result.length
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'architect', result[0][:role]
    assert_equal 'claude', result[1][:name]
    assert_equal 'security', result[1][:role]
  end

  # Test invalid syntax: leading equals
  def test_parse_invalid_syntax_leading_equals
    error = assert_raises(ArgumentError) do
      AIA::CLIParser.send(:parse_models_with_roles, '=architect')
    end
    assert_match(/Invalid model syntax/, error.message)
  end

  # Test invalid syntax: trailing equals
  def test_parse_invalid_syntax_trailing_equals
    error = assert_raises(ArgumentError) do
      AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=')
    end
    assert_match(/Invalid model syntax/, error.message)
  end

  # Test role validation: nonexistent role
  def test_validate_nonexistent_role
    error = assert_raises(ArgumentError) do
      AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=nonexistent')
    end
    assert_match(/Role file not found/, error.message)
    assert_match(/Available roles:/, error.message)
    assert_match(/architect/, error.message)
  end

  # Test role validation: existing role passes
  def test_validate_existing_role
    # Should not raise error
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=architect')
    assert_equal 'architect', result[0][:role]
  end

  # Test list_available_role_names
  def test_list_available_role_names
    roles = AIA::CLIParser.send(:list_available_role_names, @temp_dir, 'roles')

    assert_includes roles, 'architect'
    assert_includes roles, 'security'
    assert_includes roles, 'performance'
    assert_includes roles, 'specialized/senior_architect'
  end

  # Test complex real-world scenario
  def test_complex_real_world_scenario
    result = AIA::CLIParser.send(:parse_models_with_roles,
      'gpt-4o=architect,gpt-4o=security,claude=performance,gemini'
    )

    assert_equal 4, result.length

    # gpt-4o #1
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'architect', result[0][:role]
    assert_equal 1, result[0][:instance]
    assert_equal 'gpt-4o', result[0][:internal_id]

    # gpt-4o #2
    assert_equal 'gpt-4o', result[1][:name]
    assert_equal 'security', result[1][:role]
    assert_equal 2, result[1][:instance]
    assert_equal 'gpt-4o#2', result[1][:internal_id]

    # claude #1
    assert_equal 'claude', result[2][:name]
    assert_equal 'performance', result[2][:role]
    assert_equal 1, result[2][:instance]
    assert_equal 'claude', result[2][:internal_id]

    # gemini #1 (no role)
    assert_equal 'gemini', result[3][:name]
    assert_nil result[3][:role]
    assert_equal 1, result[3][:instance]
    assert_equal 'gemini', result[3][:internal_id]
  end
end
