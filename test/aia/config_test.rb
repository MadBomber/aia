# frozen_string_literal: true

require_relative '../test_helper'
require 'ostruct'

# Load MywayConfig and AIA config
require 'myway_config'
require_relative '../../lib/aia/config/model_spec'
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

  def test_mcp_use_defaults_to_empty_array
    config = AIA::Config.new
    assert_respond_to config, :mcp_use
    assert_kind_of Array, config.mcp_use
    assert_empty config.mcp_use
  end

  def test_mcp_skip_defaults_to_empty_array
    config = AIA::Config.new
    assert_respond_to config, :mcp_skip
    assert_kind_of Array, config.mcp_skip
    assert_empty config.mcp_skip
  end

  def test_mcp_use_override
    config = AIA::Config.new(overrides: { mcp_use: ['github'] })
    assert_equal ['github'], config.mcp_use
  end

  def test_mcp_skip_override
    config = AIA::Config.new(overrides: { mcp_skip: ['playwright'] })
    assert_equal ['playwright'], config.mcp_skip
  end

  def test_mcp_list_runtime_attribute
    config = AIA::Config.new
    assert_respond_to config, :mcp_list
    assert_nil config.mcp_list

    config.mcp_list = true
    assert_equal true, config.mcp_list
  end

  def test_to_h_includes_mcp_use_and_skip
    config = AIA::Config.new
    hash = config.to_h
    assert hash.key?(:mcp_use)
    assert hash.key?(:mcp_skip)
  end

  # =========================================================================
  # Extra config file tests (-c / --config-file)
  # =========================================================================

  def test_extra_config_file_overrides_prompts_dir
    config_file = create_temp_config(<<~YAML)
      prompts:
        dir: /tmp/test_prompts
    YAML

    config = AIA::Config.new(overrides: { extra_config_file: config_file })
    assert_equal '/tmp/test_prompts', config.prompts.dir
  end

  def test_extra_config_file_overrides_model
    # Clear AIA_MODEL env var so it doesn't interfere
    original_model = ENV.delete('AIA_MODEL')

    config_file = create_temp_config(<<~YAML)
      models:
        - name: ollama/qwen3
    YAML

    config = AIA::Config.new(overrides: { extra_config_file: config_file })
    assert_equal 1, config.models.size
    assert_equal 'ollama/qwen3', config.models.first.name
  ensure
    ENV['AIA_MODEL'] = original_model if original_model
  end

  def test_extra_config_file_preserves_unset_defaults
    config_file = create_temp_config(<<~YAML)
      llm:
        temperature: 0.2
    YAML

    config = AIA::Config.new(overrides: { extra_config_file: config_file })
    assert_equal 0.2, config.llm.temperature
    # max_tokens should still have its bundled default
    assert_equal 2048, config.llm.max_tokens
  end

  def test_extra_config_file_resets_to_defaults_not_user_config
    # Without -c, the user's personal config may set a custom model.
    # With -c, only bundled defaults + the config file should apply.
    original_model = ENV.delete('AIA_MODEL')

    config_file = create_temp_config(<<~YAML)
      llm:
        temperature: 0.1
    YAML

    config = AIA::Config.new(overrides: { extra_config_file: config_file })

    # Model should be the bundled default (gpt-4o-mini), not whatever
    # the user has in their personal ~/.config/aia/aia.yml
    assert_equal 'gpt-4o-mini', config.models.first.name
    # prompts.dir should be the bundled default, not a user override
    assert_equal File.expand_path('~/.prompts'), config.prompts.dir
  ensure
    ENV['AIA_MODEL'] = original_model if original_model
  end

  def test_cli_overrides_take_precedence_over_extra_config
    config_file = create_temp_config(<<~YAML)
      llm:
        temperature: 0.2
    YAML

    config = AIA::Config.new(overrides: {
      extra_config_file: config_file,
      temperature: 0.9
    })
    assert_equal 0.9, config.llm.temperature
  end

  def test_extra_config_file_supports_defaults_wrapper
    config_file = create_temp_config(<<~YAML)
      defaults:
        llm:
          temperature: 0.3
    YAML

    config = AIA::Config.new(overrides: { extra_config_file: config_file })
    assert_equal 0.3, config.llm.temperature
  end

  def test_extra_config_file_stores_path
    config_file = create_temp_config(<<~YAML)
      llm:
        temperature: 0.5
    YAML

    config = AIA::Config.new(overrides: { extra_config_file: config_file })
    assert_equal File.expand_path(config_file), config.paths[:extra_config_file]
  end

  def test_extra_config_file_merges_flags
    config_file = create_temp_config(<<~YAML)
      flags:
        debug: true
    YAML

    config = AIA::Config.new(overrides: { extra_config_file: config_file })
    assert_equal true, config.flags.debug
    # chat should still have its default
    assert_equal false, config.flags.chat
  end

  def test_extra_config_file_missing_file_does_not_crash
    # exit is overridden in test_helper to not terminate;
    # verify config still initializes when file is missing
    original_stderr = $stderr
    $stderr = StringIO.new

    config = AIA::Config.new(overrides: { extra_config_file: '/nonexistent/path.yml' })
    assert_instance_of AIA::Config, config
  ensure
    $stderr = original_stderr
  end

  private

  def create_temp_config(yaml_content)
    require 'tempfile'
    file = Tempfile.new(['aia_test_config', '.yml'])
    file.write(yaml_content)
    file.close
    @temp_files ||= []
    @temp_files << file
    file.path
  end
end
