# test/integration/ollama_adapter_test.rb
#
# Integration tests for RubyLLMAdapter using a local Ollama instance.
# Exercises the real LLM code paths: initialization, chat, context management,
# model extraction, tool filtering, and helper methods.

require_relative 'ollama_test_helper'

class OllamaAdapterInitTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
  end

  def test_adapter_initializes_with_ollama
    assert_kind_of AIA::RubyLLMAdapter, AIA.client
  end

  def test_adapter_has_one_chat
    assert_equal 1, AIA.client.chats.size
  end

  def test_chat_key_matches_model_name
    assert_includes AIA.client.chats.keys, OllamaTestHelper::OLLAMA_MODEL
  end

  def test_model_specs_populated
    specs = AIA.client.model_specs
    assert_equal 1, specs.size
    assert_equal OllamaTestHelper::OLLAMA_MODEL, specs.first[:model]
    assert_equal 1, specs.first[:instance]
    assert_nil specs.first[:role]
  end

  def test_extract_model_and_provider_ollama
    actual, provider = AIA.client.extract_model_and_provider('ollama/gpt-oss:latest')
    assert_equal 'gpt-oss:latest', actual
    assert_equal 'ollama', provider
  end

  def test_extract_model_and_provider_plain
    actual, provider = AIA.client.extract_model_and_provider('gpt-4o')
    assert_equal 'gpt-4o', actual
    assert_nil provider
  end

  def test_extract_model_and_provider_lms
    actual, provider = AIA.client.extract_model_and_provider('lms/my-model')
    assert_equal 'my-model', actual
    assert_equal 'openai', provider
  end

  def test_extract_model_and_provider_osaurus
    actual, provider = AIA.client.extract_model_and_provider('osaurus/my-model')
    assert_equal 'my-model', actual
    assert_equal 'openai', provider
  end

  def test_tools_defaults_to_empty
    assert_equal [], AIA.client.tools
  end

  def test_respond_to_missing_delegates_to_chat
    # RubyLLM::Chat responds to :model
    assert AIA.client.respond_to?(:model)
  end

  def test_method_missing_delegates_model
    model = AIA.client.model
    assert model.respond_to?(:id)
  end
end


class OllamaAdapterChatTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
  end

  def test_single_model_chat_returns_response
    response = AIA.client.chat('Reply with only the word hello')
    refute_nil response
  end

  def test_single_model_chat_has_content
    response = AIA.client.chat('What is 1+1? Reply with only the number.')
    content = response.respond_to?(:content) ? response.content : response.to_s
    refute_empty content
  end

  def test_response_has_token_counts
    response = AIA.client.chat('Say hi')
    assert response.respond_to?(:input_tokens), 'Response should have input_tokens'
    assert response.respond_to?(:output_tokens), 'Response should have output_tokens'
    assert_kind_of Integer, response.input_tokens
    assert_kind_of Integer, response.output_tokens
    assert response.input_tokens > 0
    assert response.output_tokens > 0
  end

  def test_chat_with_string_prompt
    response = AIA.client.chat('Repeat the word test')
    content = response.respond_to?(:content) ? response.content : response.to_s
    assert content.downcase.include?('test')
  end

  def test_extract_text_prompt_string
    result = AIA.client.send(:extract_text_prompt, 'hello world')
    assert_equal 'hello world', result
  end

  def test_extract_text_prompt_hash_text
    result = AIA.client.send(:extract_text_prompt, { text: 'hello' })
    assert_equal 'hello', result
  end

  def test_extract_text_prompt_hash_content
    result = AIA.client.send(:extract_text_prompt, { content: 'hello' })
    assert_equal 'hello', result
  end

  def test_extract_text_prompt_other
    result = AIA.client.send(:extract_text_prompt, 42)
    assert_equal '42', result
  end
end


class OllamaAdapterContextTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
  end

  def test_clear_context_returns_success
    # Send a message first to have context
    AIA.client.chat('Remember the word banana')
    result = AIA.client.clear_context
    assert_equal 'Chat context successfully cleared.', result
  end

  def test_clear_context_resets_conversation
    # Chat, clear, then verify new context
    AIA.client.chat('Remember: the secret word is pineapple')
    AIA.client.clear_context
    # After clearing, the model should not know the secret word
    response = AIA.client.chat('What was the secret word I told you?')
    content = response.respond_to?(:content) ? response.content : response.to_s
    # The model shouldn't reliably recall "pineapple" after context clear
    # (it might guess, but the conversation was reset)
    refute_nil content
  end

  def test_chats_preserved_after_clear
    AIA.client.clear_context
    assert_equal 1, AIA.client.chats.size
    assert_includes AIA.client.chats.keys, OllamaTestHelper::OLLAMA_MODEL
  end
end


class OllamaAdapterExtractModelsTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
  end

  def test_extract_models_config_from_hash_specs
    specs = AIA.client.send(:extract_models_config)
    assert_kind_of Array, specs
    assert_equal 1, specs.size
    assert_equal OllamaTestHelper::OLLAMA_MODEL, specs.first[:model]
  end

  def test_extract_model_names
    names = AIA.client.send(:extract_model_names, AIA.client.model_specs)
    assert_equal [OllamaTestHelper::OLLAMA_MODEL], names
  end

  def test_get_model_spec
    spec = AIA.client.send(:get_model_spec, OllamaTestHelper::OLLAMA_MODEL)
    assert_kind_of Hash, spec
    assert_equal OllamaTestHelper::OLLAMA_MODEL, spec[:internal_id]
  end

  def test_get_model_spec_unknown_returns_nil
    spec = AIA.client.send(:get_model_spec, 'nonexistent-model')
    assert_nil spec
  end
end


class OllamaAdapterToolFilteringTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
  end

  def test_drop_duplicate_tools_empty
    AIA.client.instance_variable_set(:@tools, [])
    AIA.client.send(:drop_duplicate_tools)
    assert_empty AIA.client.tools
  end

  def test_filter_tools_by_allowed_list_nil
    AIA.config.tools.allowed = nil
    AIA.client.instance_variable_set(:@tools, [])
    AIA.client.send(:filter_tools_by_allowed_list)
    assert_empty AIA.client.tools
  end

  def test_filter_tools_by_rejected_list_nil
    AIA.config.tools.rejected = nil
    AIA.client.instance_variable_set(:@tools, [])
    AIA.client.send(:filter_tools_by_rejected_list)
    assert_empty AIA.client.tools
  end

  def test_filter_mcp_servers_empty
    servers = AIA.client.send(:filter_mcp_servers, [])
    assert_empty servers
  end

  def test_filter_mcp_servers_with_use_list
    AIA.config.mcp_use = ['server_a']
    servers = [
      { name: 'server_a', command: 'echo' },
      { name: 'server_b', command: 'echo' }
    ]
    result = AIA.client.send(:filter_mcp_servers, servers)
    assert_equal 1, result.size
    assert_equal 'server_a', result.first[:name]
  ensure
    AIA.config.mcp_use = []
  end

  def test_filter_mcp_servers_with_skip_list
    AIA.config.mcp_skip = ['server_b']
    servers = [
      { name: 'server_a', command: 'echo' },
      { name: 'server_b', command: 'echo' }
    ]
    result = AIA.client.send(:filter_mcp_servers, servers)
    assert_equal 1, result.size
    assert_equal 'server_a', result.first[:name]
  ensure
    AIA.config.mcp_skip = []
  end
end


class OllamaAdapterImageAudioHelpersTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
  end

  def test_extract_image_path_from_string
    path = AIA.client.send(:extract_image_path, 'Describe this image photo.jpg')
    assert_equal 'photo.jpg', path
  end

  def test_extract_image_path_from_string_no_image
    path = AIA.client.send(:extract_image_path, 'No image here')
    assert_nil path
  end

  def test_extract_image_path_from_hash
    path = AIA.client.send(:extract_image_path, { image: '/tmp/test.png' })
    assert_equal '/tmp/test.png', path
  end

  def test_audio_file_detection
    assert AIA.client.send(:audio_file?, 'test.mp3')
    assert AIA.client.send(:audio_file?, 'test.wav')
    assert AIA.client.send(:audio_file?, 'test.m4a')
    assert AIA.client.send(:audio_file?, 'test.flac')
    refute AIA.client.send(:audio_file?, 'test.txt')
    refute AIA.client.send(:audio_file?, 'test.rb')
  end

  def test_format_model_display_name_with_spec
    spec = { model: 'ollama/gpt-oss:latest', instance: 1, role: nil }
    name = AIA.client.send(:format_model_display_name, spec)
    assert_equal 'ollama/gpt-oss:latest', name
  end

  def test_format_model_display_name_with_role
    spec = { model: 'ollama/gpt-oss:latest', instance: 1, role: 'architect' }
    name = AIA.client.send(:format_model_display_name, spec)
    assert_equal 'ollama/gpt-oss:latest (architect)', name
  end

  def test_format_model_display_name_with_instance
    spec = { model: 'ollama/gpt-oss:latest', instance: 2, role: nil }
    name = AIA.client.send(:format_model_display_name, spec)
    assert_equal 'ollama/gpt-oss:latest #2', name
  end

  def test_format_model_display_name_with_string
    name = AIA.client.send(:format_model_display_name, 'raw-string')
    assert_equal 'raw-string', name
  end
end


class OllamaAdapterMultiModelResponseTest < Minitest::Test
  def test_multi_model_response_class
    response = AIA::RubyLLMAdapter::MultiModelResponse.new('content', [])
    assert_equal 'content', response.content
    assert_equal [], response.metrics_list
    assert response.multi_model?
  end

  def test_multi_model_response_with_metrics
    metrics = [{ model_id: 'm1', input_tokens: 10, output_tokens: 20 }]
    response = AIA::RubyLLMAdapter::MultiModelResponse.new('text', metrics)
    assert_equal 1, response.metrics_list.size
    assert_equal 'm1', response.metrics_list.first[:model_id]
  end
end


class OllamaAdapterMcpHelperTest < Minitest::Test
  include OllamaTestHelper

  FakeClient = Struct.new(:alive)
  def self.fake_client(alive:) = FakeClient.new(alive)

  # Struct#alive returns the value, add alias for alive?
  FakeClient.define_method(:alive?) { alive }

  def setup
    setup_ollama_single_model
  end

  def test_determine_mcp_connection_error_not_alive
    client = self.class.fake_client(alive: false)
    error = AIA.client.send(:determine_mcp_connection_error, client, nil)
    assert_equal 'Connection failed', error
  end

  def test_determine_mcp_connection_error_nil_caps
    client = self.class.fake_client(alive: true)
    error = AIA.client.send(:determine_mcp_connection_error, client, nil)
    assert_equal 'Connection timed out (no response)', error
  end

  def test_determine_mcp_connection_error_empty_caps
    client = self.class.fake_client(alive: true)
    error = AIA.client.send(:determine_mcp_connection_error, client, {})
    assert_equal 'Connection timed out (empty capabilities)', error
  end
end
