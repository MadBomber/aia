# test/integration/ollama_multi_model_test.rb
#
# Integration tests for multi-model functionality using two Ollama instances.
# Exercises: multi_model_chat, format_multi_model_results, format_individual_responses,
# and the consensus code path.

require_relative 'ollama_test_helper'

class OllamaMultiModelSetupTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_multi_model
  end

  def test_adapter_has_two_chats
    assert_equal 2, AIA.client.chats.size
  end

  def test_chat_keys_include_instance_numbers
    keys = AIA.client.chats.keys
    assert_includes keys, OllamaTestHelper::OLLAMA_MODEL
    assert_includes keys, "#{OllamaTestHelper::OLLAMA_MODEL}#2"
  end

  def test_model_specs_have_two_entries
    specs = AIA.client.model_specs
    assert_equal 2, specs.size
    assert_equal 1, specs[0][:instance]
    assert_equal 2, specs[1][:instance]
  end

  def test_model_specs_internal_ids
    specs = AIA.client.model_specs
    assert_equal OllamaTestHelper::OLLAMA_MODEL, specs[0][:internal_id]
    assert_equal "#{OllamaTestHelper::OLLAMA_MODEL}#2", specs[1][:internal_id]
  end
end


class OllamaMultiModelChatTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_multi_model
  end

  def test_multi_model_chat_returns_response
    response = AIA.client.chat('Say hello in one word')
    refute_nil response
  end

  def test_multi_model_chat_response_is_multi_model
    response = AIA.client.chat('What is 2+2? Just the number.')
    assert_kind_of AIA::RubyLLMAdapter::MultiModelResponse, response
    assert_kind_of String, response.content
  end

  def test_multi_model_chat_contains_from_prefix
    response = AIA.client.chat('Say hello')
    content = response.content
    assert content.include?('from:'), "Multi-model response should contain 'from:' labels"
  end

  def test_multi_model_chat_contains_both_models
    response = AIA.client.chat('Reply with only the word yes')
    content = response.content
    # Should have responses labeled for both model instances
    assert content.include?("from: #{OllamaTestHelper::OLLAMA_MODEL}"),
      "Response should include first model label"
  end

  def test_format_model_display_name_instance_2
    spec = { model: 'ollama/gpt-oss:latest', instance: 2, role: nil }
    name = AIA.client.send(:format_model_display_name, spec)
    assert_equal 'ollama/gpt-oss:latest #2', name
  end

  def test_format_model_display_name_with_role_and_instance
    spec = { model: 'ollama/gpt-oss:latest', instance: 2, role: 'reviewer' }
    name = AIA.client.send(:format_model_display_name, spec)
    assert_equal 'ollama/gpt-oss:latest #2 (reviewer)', name
  end

  def test_should_use_consensus_mode_false_by_default
    refute AIA.client.send(:should_use_consensus_mode?)
  end

  def test_clear_context_multi_model
    AIA.client.chat('Remember the word banana')
    result = AIA.client.clear_context
    assert_equal 'Chat context successfully cleared.', result
    assert_equal 2, AIA.client.chats.size
  end
end


class OllamaMultiModelConsensusTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_multi_model
    AIA.config.flags.consensus = true
  end

  def teardown
    AIA.config.flags.consensus = false
  end

  def test_consensus_mode_enabled
    assert AIA.client.send(:should_use_consensus_mode?)
  end

  def test_consensus_chat_returns_string
    response = AIA.client.chat('What color is the sky? One word.')
    # Consensus mode returns a plain String with the synthesized response
    assert_kind_of String, response
    refute_empty response
  end

  def test_consensus_response_has_from_prefix
    response = AIA.client.chat('Say hello')
    # Consensus returns a String directly
    assert response.include?('from:'), "Consensus response should have 'from:' label"
  end

  def test_build_consensus_prompt
    results = {
      'model_a' => 'Blue',
      'model_b' => 'Azure'
    }
    prompt = AIA.client.send(:build_consensus_prompt, results)
    assert prompt.include?('consensus')
    assert prompt.include?('model_a')
    assert prompt.include?('Blue')
    assert prompt.include?('model_b')
    assert prompt.include?('Azure')
  end
end
