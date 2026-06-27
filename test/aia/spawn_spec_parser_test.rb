# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/aia'

class SpawnSpecParserTest < Minitest::Test
  def test_parses_name_provider_model_and_system_prompt
    spec = AIA::SpawnSpecParser.parse(%w[researcher ollama/qwen3.6:latest You are careful])

    assert_equal 'researcher', spec[:name]
    assert_equal 'qwen3.6:latest', spec[:model]
    assert_equal 'ollama', spec[:provider]
    assert_equal 'You are careful', spec[:system_prompt]
  end

  def test_cloud_model_has_nil_provider
    spec = AIA::SpawnSpecParser.parse(%w[helper gpt-4o write tests])

    assert_equal 'gpt-4o', spec[:model]
    assert_nil spec[:provider]
    assert_equal 'write tests', spec[:system_prompt]
  end

  def test_lms_prefix_maps_to_openai_provider
    spec = AIA::SpawnSpecParser.parse(%w[local lms/my-model hello])

    assert_equal 'my-model', spec[:model]
    assert_equal 'openai', spec[:provider]
  end

  def test_inherit_token_keeps_parent_model_and_provider
    spec = AIA::SpawnSpecParser.parse(%w[helper - you are helpful])

    assert_nil spec[:model]
    assert_nil spec[:provider]
    assert_equal 'you are helpful', spec[:system_prompt]
  end

  def test_missing_system_prompt_is_nil
    spec = AIA::SpawnSpecParser.parse(%w[helper ollama/qwen3.6:latest])

    assert_equal 'qwen3.6:latest', spec[:model]
    assert_nil spec[:system_prompt]
  end

  def test_skill_tokens_are_extracted_from_the_spec
    spec = AIA::SpawnSpecParser.parse(%w[reviewer ollama/qwen3.6:latest skill:security focus on auth])

    assert_equal 'reviewer', spec[:name]
    assert_equal 'qwen3.6:latest', spec[:model]
    assert_equal %w[security], spec[:skills]
    assert_equal 'focus on auth', spec[:system_prompt]
  end

  def test_skill_only_recruit_inherits_model_and_has_no_prompt
    spec = AIA::SpawnSpecParser.parse(%w[reviewer skill:security-review])

    assert_nil spec[:model]
    assert_nil spec[:provider]
    assert_nil spec[:system_prompt]
    assert_equal %w[security-review], spec[:skills]
  end

  def test_comma_and_repeated_skill_tokens_collect_all_ids
    spec = AIA::SpawnSpecParser.parse(%w[reviewer - skill:a,b skill:c go])

    assert_equal %w[a b c], spec[:skills]
    assert_equal 'go', spec[:system_prompt]
  end

  def test_no_skills_yields_empty_list
    spec = AIA::SpawnSpecParser.parse(%w[helper gpt-4o hi])

    assert_empty spec[:skills]
  end
end
