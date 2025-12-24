# frozen_string_literal: true

require_relative '../test_helper'
require 'ostruct'

# Stub anyway_config before loading AIA config
require 'anyway_config'
require_relative '../../lib/aia/config/config_section'
require_relative '../../lib/aia/config/model_spec'
require_relative '../../lib/aia/config/defaults_loader'
require_relative '../../lib/aia/config'

class ConfigTest < Minitest::Test
  def setup
    # Reset any cached config state
    @original_env = ENV.to_h.dup
  end

  def teardown
    # Restore original environment
    ENV.clear
    @original_env.each { |k, v| ENV[k] = v }
  end

  def test_config_creation
    # Test that Config can be instantiated
    config = AIA::Config.new
    assert_instance_of AIA::Config, config
  end

  def test_config_has_llm_section
    config = AIA::Config.new
    assert_respond_to config, :llm
    assert_instance_of AIA::ConfigSection, config.llm
  end

  def test_config_has_prompts_section
    config = AIA::Config.new
    assert_respond_to config, :prompts
    assert_instance_of AIA::ConfigSection, config.prompts
  end

  def test_config_has_flags_section
    config = AIA::Config.new
    assert_respond_to config, :flags
    assert_instance_of AIA::ConfigSection, config.flags
  end

  def test_config_has_default_temperature
    config = AIA::Config.new
    assert config.llm.key?(:temperature), "LLM section should have temperature"
    assert_kind_of Numeric, config.llm.temperature
  end

  def test_config_has_default_max_tokens
    config = AIA::Config.new
    assert config.llm.key?(:max_tokens), "LLM section should have max_tokens"
    assert_kind_of Integer, config.llm.max_tokens
  end

  def test_config_nested_llm_section
    config = AIA::Config.new

    # Test LLM section has expected keys
    assert config.llm.key?(:adapter), "LLM section should have adapter key"
    assert config.llm.key?(:temperature), "LLM section should have temperature key"
    assert config.llm.key?(:max_tokens), "LLM section should have max_tokens key"
  end

  def test_config_nested_prompts_section
    config = AIA::Config.new

    # Test prompts section has expected keys
    assert config.prompts.key?(:dir), "Prompts section should have dir key"
    assert config.prompts.key?(:roles_prefix), "Prompts section should have roles_prefix key"
  end

  def test_config_nested_flags_section
    config = AIA::Config.new

    # Test flags section has expected keys
    assert config.flags.key?(:chat), "Flags section should have chat key"
    assert config.flags.key?(:debug), "Flags section should have debug key"
    assert config.flags.key?(:verbose), "Flags section should have verbose key"
  end

  def test_config_to_h
    config = AIA::Config.new
    hash = config.to_h

    assert_instance_of Hash, hash
    assert hash.key?(:llm)
    assert hash.key?(:prompts)
    assert hash.key?(:flags)
    assert hash.key?(:models)
  end

  def test_models_array
    config = AIA::Config.new
    assert_respond_to config, :models
    assert_kind_of Array, config.models
  end

  def test_pipeline_array
    config = AIA::Config.new
    assert_respond_to config, :pipeline
    assert_kind_of Array, config.pipeline
  end

  def test_context_files_array
    config = AIA::Config.new
    assert_respond_to config, :context_files
    assert_kind_of Array, config.context_files
  end

  def test_runtime_attributes
    config = AIA::Config.new

    # Test runtime attrs can be set
    config.prompt_id = 'test_prompt'
    assert_equal 'test_prompt', config.prompt_id

    config.tool_names = 'tool1, tool2'
    assert_equal 'tool1, tool2', config.tool_names
  end
end
