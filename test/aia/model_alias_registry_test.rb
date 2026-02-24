# frozen_string_literal: true
# test/aia/model_alias_registry_test.rb

require_relative '../test_helper'

class ModelAliasRegistryTest < Minitest::Test
  def setup
    @registry = AIA::ModelAliasRegistry.new
  end

  def teardown
    super
  end

  # =========================================================================
  # resolve - known short names
  # =========================================================================

  def test_resolve_claude_returns_sonnet
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("claude")
  end

  def test_resolve_sonnet_returns_sonnet
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("sonnet")
  end

  def test_resolve_opus_returns_opus
    assert_equal "claude-opus-4-20250514", @registry.resolve("opus")
  end

  def test_resolve_haiku_returns_haiku
    assert_equal "claude-haiku-4-5-20251001", @registry.resolve("haiku")
  end

  def test_resolve_gpt4_returns_gpt4o
    assert_equal "gpt-4o", @registry.resolve("gpt4")
  end

  def test_resolve_gpt4o_returns_gpt4o
    assert_equal "gpt-4o", @registry.resolve("gpt4o")
  end

  def test_resolve_gpt4mini_returns_gpt4o_mini
    assert_equal "gpt-4o-mini", @registry.resolve("gpt4mini")
  end

  def test_resolve_gemini_returns_gemini_flash
    assert_equal "gemini-2.0-flash", @registry.resolve("gemini")
  end

  def test_resolve_flash_returns_gemini_flash
    assert_equal "gemini-2.0-flash", @registry.resolve("flash")
  end

  def test_resolve_llama_returns_llama
    assert_equal "llama-3.1-70b", @registry.resolve("llama")
  end

  # =========================================================================
  # resolve - unknown names
  # =========================================================================

  def test_resolve_unknown_name_returns_name_itself
    assert_equal "some-custom-model-v3", @registry.resolve("some-custom-model-v3")
  end

  def test_resolve_unknown_fully_qualified_model_returns_as_is
    assert_equal "ollama/qwen3:8b", @registry.resolve("ollama/qwen3:8b")
  end

  # =========================================================================
  # resolve - normalization
  # =========================================================================

  def test_resolve_normalizes_case
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("Claude")
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("CLAUDE")
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("cLaUdE")
  end

  def test_resolve_normalizes_leading_trailing_whitespace
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("  claude  ")
    assert_equal "gpt-4o", @registry.resolve(" gpt4 ")
  end

  def test_resolve_normalizes_internal_hyphens_and_underscores
    # normalize_key strips hyphens, underscores, and spaces
    # "gpt-4-o" becomes "gpt4o" which matches the alias
    assert_equal "gpt-4o", @registry.resolve("gpt-4-o")
    assert_equal "gpt-4o", @registry.resolve("gpt_4_o")
  end

  # =========================================================================
  # resolve - provider names
  # =========================================================================

  def test_resolve_anthropic_returns_claude_sonnet
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("anthropic")
  end

  def test_resolve_openai_returns_gpt4o
    assert_equal "gpt-4o", @registry.resolve("openai")
  end

  def test_resolve_google_returns_gemini_flash
    assert_equal "gemini-2.0-flash", @registry.resolve("google")
  end

  def test_resolve_meta_returns_llama
    assert_equal "llama-3.1-70b", @registry.resolve("meta")
  end

  # =========================================================================
  # resolve - capability descriptors
  # =========================================================================

  def test_resolve_fast_returns_haiku
    assert_equal "claude-haiku-4-5-20251001", @registry.resolve("fast")
  end

  def test_resolve_cheap_returns_gpt4o_mini
    assert_equal "gpt-4o-mini", @registry.resolve("cheap")
  end

  def test_resolve_best_returns_opus
    assert_equal "claude-opus-4-20250514", @registry.resolve("best")
  end

  def test_resolve_coding_returns_sonnet
    assert_equal "claude-sonnet-4-20250514", @registry.resolve("coding")
  end

  def test_resolve_vision_returns_gpt4o
    assert_equal "gpt-4o", @registry.resolve("vision")
  end

  # =========================================================================
  # resolve_multiple
  # =========================================================================

  def test_resolve_multiple_with_comma_separated_names
    result = @registry.resolve_multiple("claude, gemini")

    assert_equal 2, result.size
    assert_includes result, "claude-sonnet-4-20250514"
    assert_includes result, "gemini-2.0-flash"
  end

  def test_resolve_multiple_with_and_separated_names
    result = @registry.resolve_multiple("claude and gemini")

    assert_equal 2, result.size
    assert_includes result, "claude-sonnet-4-20250514"
    assert_includes result, "gemini-2.0-flash"
  end

  def test_resolve_multiple_with_ampersand_separated_names
    result = @registry.resolve_multiple("opus & haiku")

    assert_equal 2, result.size
    assert_includes result, "claude-opus-4-20250514"
    assert_includes result, "claude-haiku-4-5-20251001"
  end

  def test_resolve_multiple_with_plus_separated_names
    result = @registry.resolve_multiple("gpt4 + llama")

    assert_equal 2, result.size
    assert_includes result, "gpt-4o"
    assert_includes result, "llama-3.1-70b"
  end

  def test_resolve_multiple_deduplicates
    # "claude" and "sonnet" both resolve to the same model
    result = @registry.resolve_multiple("claude, sonnet")

    assert_equal 1, result.size
    assert_equal "claude-sonnet-4-20250514", result.first
  end

  def test_resolve_multiple_with_single_name
    result = @registry.resolve_multiple("claude")

    assert_equal 1, result.size
    assert_equal "claude-sonnet-4-20250514", result.first
  end

  def test_resolve_multiple_with_mixed_known_and_unknown
    result = @registry.resolve_multiple("claude, my-custom-model")

    assert_equal 2, result.size
    assert_includes result, "claude-sonnet-4-20250514"
    assert_includes result, "my-custom-model"
  end

  def test_resolve_multiple_with_three_names
    result = @registry.resolve_multiple("claude, gemini, gpt4")

    assert_equal 3, result.size
    assert_includes result, "claude-sonnet-4-20250514"
    assert_includes result, "gemini-2.0-flash"
    assert_includes result, "gpt-4o"
  end

  # =========================================================================
  # known?
  # =========================================================================

  def test_known_returns_true_for_known_aliases
    assert @registry.known?("claude")
    assert @registry.known?("sonnet")
    assert @registry.known?("opus")
    assert @registry.known?("haiku")
    assert @registry.known?("gpt4")
    assert @registry.known?("gemini")
    assert @registry.known?("fast")
    assert @registry.known?("best")
    assert @registry.known?("anthropic")
  end

  def test_known_returns_false_for_unknown_names
    refute @registry.known?("totally-unknown-model")
    refute @registry.known?("my-custom-model")
    refute @registry.known?("")
  end

  def test_known_is_case_insensitive
    assert @registry.known?("Claude")
    assert @registry.known?("OPUS")
    assert @registry.known?("Haiku")
  end

  def test_known_handles_whitespace
    assert @registry.known?("  claude  ")
    assert @registry.known?(" gpt4 ")
  end

  # =========================================================================
  # Custom aliases
  # =========================================================================

  def test_custom_aliases_override_defaults
    custom_registry = AIA::ModelAliasRegistry.new("claude" => "my-custom-claude-v9")

    assert_equal "my-custom-claude-v9", custom_registry.resolve("claude")
  end

  def test_custom_aliases_add_new_entries
    custom_registry = AIA::ModelAliasRegistry.new("mymodel" => "custom/mymodel-v2")

    assert_equal "custom/mymodel-v2", custom_registry.resolve("mymodel")
    assert custom_registry.known?("mymodel")
  end

  def test_custom_aliases_do_not_remove_existing_defaults
    custom_registry = AIA::ModelAliasRegistry.new("mymodel" => "custom/mymodel-v2")

    # Default aliases should still work
    assert_equal "claude-sonnet-4-20250514", custom_registry.resolve("claude")
    assert_equal "gpt-4o", custom_registry.resolve("gpt4")
  end

  def test_custom_aliases_keys_are_normalized
    custom_registry = AIA::ModelAliasRegistry.new("My-Model" => "custom/model-v1")

    assert_equal "custom/model-v1", custom_registry.resolve("mymodel")
    assert_equal "custom/model-v1", custom_registry.resolve("My-Model")
    assert_equal "custom/model-v1", custom_registry.resolve("MY_MODEL")
  end

  # =========================================================================
  # all_aliases
  # =========================================================================

  def test_all_aliases_returns_full_alias_map
    aliases = @registry.all_aliases

    assert_instance_of Hash, aliases
    assert aliases.key?("claude")
    assert aliases.key?("sonnet")
    assert aliases.key?("opus")
    assert aliases.key?("haiku")
    assert aliases.key?("gpt4")
    assert aliases.key?("gemini")
    assert aliases.key?("fast")
    assert aliases.key?("best")
    assert aliases.key?("anthropic")
    assert aliases.key?("openai")
    assert aliases.key?("google")
  end

  def test_all_aliases_returns_duplicate_not_original
    aliases = @registry.all_aliases
    aliases["injected"] = "bad-model"

    refute @registry.known?("injected"),
      "Modifying all_aliases output should not affect the registry"
  end

  def test_all_aliases_includes_custom_entries
    custom_registry = AIA::ModelAliasRegistry.new("mymodel" => "custom/v1")
    aliases = custom_registry.all_aliases

    assert aliases.key?("mymodel")
    assert_equal "custom/v1", aliases["mymodel"]
  end

  def test_all_aliases_count_matches_defaults_plus_custom
    custom_registry = AIA::ModelAliasRegistry.new("brand_new" => "model/v1")
    default_count = AIA::ModelAliasRegistry::DEFAULT_ALIASES.size

    assert_equal default_count + 1, custom_registry.all_aliases.size
  end

  # =========================================================================
  # Edge cases
  # =========================================================================

  def test_resolve_with_nil_returns_empty_string
    result = @registry.resolve(nil)
    assert_equal "", result
  end

  def test_resolve_with_empty_string_returns_empty_string
    result = @registry.resolve("")
    assert_equal "", result
  end

  def test_resolve_multiple_with_nil_returns_empty_array
    result = @registry.resolve_multiple(nil)
    assert_equal [], result
  end

  def test_resolve_multiple_with_empty_string_returns_empty_array
    result = @registry.resolve_multiple("")
    assert_equal [], result
  end

  def test_default_aliases_is_frozen
    assert AIA::ModelAliasRegistry::DEFAULT_ALIASES.frozen?,
      "DEFAULT_ALIASES constant should be frozen"
  end
end
