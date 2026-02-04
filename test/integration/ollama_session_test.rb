# test/integration/ollama_session_test.rb
#
# Integration tests for Session using a local Ollama instance.
# Tests the non-interactive parts: parse_multi_model_response,
# should_start_chat_immediately?, and process pipeline infrastructure.

require_relative 'ollama_test_helper'

class OllamaSessionParseResponseTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
    prompt_handler = AIA::PromptHandler.new
    @session = AIA::Session.new(prompt_handler)
  end

  def test_parse_multi_model_response_empty
    result = @session.send(:parse_multi_model_response, '')
    assert_equal({}, result)
  end

  def test_parse_multi_model_response_nil
    result = @session.send(:parse_multi_model_response, nil)
    assert_equal({}, result)
  end

  def test_parse_multi_model_response_single_model
    input = "from: ollama/gpt-oss:latest\nHello world\n"
    result = @session.send(:parse_multi_model_response, input)
    assert_equal 1, result.size
    assert_equal 'Hello world', result['ollama/gpt-oss:latest']
  end

  def test_parse_multi_model_response_two_models
    input = "from: model_a\nResponse A\n\nfrom: model_b\nResponse B\n"
    result = @session.send(:parse_multi_model_response, input)
    assert_equal 2, result.size
    assert_equal 'Response A', result['model_a']
    assert_equal 'Response B', result['model_b']
  end

  def test_parse_multi_model_response_with_instance_number
    input = "from: ollama/gpt-oss:latest #2\nReply here\n"
    result = @session.send(:parse_multi_model_response, input)
    assert_equal 1, result.size
    assert result.key?('ollama/gpt-oss:latest#2')
  end

  def test_parse_multi_model_response_with_role
    input = "from: ollama/gpt-oss:latest (architect)\nDesign plan\n"
    result = @session.send(:parse_multi_model_response, input)
    assert_equal 1, result.size
    assert result.key?('ollama/gpt-oss:latest')
  end

  def test_parse_multi_model_response_with_instance_and_role
    input = "from: ollama/gpt-oss:latest #2 (reviewer)\nLooks good\n"
    result = @session.send(:parse_multi_model_response, input)
    assert_equal 1, result.size
    assert result.key?('ollama/gpt-oss:latest#2')
    assert_equal 'Looks good', result['ollama/gpt-oss:latest#2']
  end

  def test_parse_multi_model_response_multiline_content
    input = "from: model_a\nLine 1\nLine 2\nLine 3\n"
    result = @session.send(:parse_multi_model_response, input)
    assert result['model_a'].include?('Line 1')
    assert result['model_a'].include?('Line 3')
  end
end


class OllamaSessionChatFlagsTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
    AIA.config.flags.chat = false
    AIA.config.pipeline = []
    prompt_handler = AIA::PromptHandler.new
    @session = AIA::Session.new(prompt_handler)
  end

  def test_should_start_chat_immediately_false_no_chat
    AIA.config.flags.chat = false
    refute @session.send(:should_start_chat_immediately?)
  end

  def test_should_start_chat_immediately_true_empty_pipeline
    AIA.config.flags.chat = true
    AIA.config.pipeline = []
    assert @session.send(:should_start_chat_immediately?)
  end

  def test_should_start_chat_immediately_false_with_pipeline
    AIA.config.flags.chat = true
    AIA.config.pipeline = ['some_prompt']
    refute @session.send(:should_start_chat_immediately?)
  end

  def test_add_context_files_empty
    result = @session.send(:add_context_files, 'hello')
    assert_equal 'hello', result
  end

  def test_add_context_files_with_file
    Tempfile.create(['ctx', '.txt']) do |f|
      f.write('context content here')
      f.flush

      AIA.config.context_files = [f.path]
      result = @session.send(:add_context_files, 'prompt text')
      assert result.include?('prompt text')
      assert result.include?('context content here')
    end
  ensure
    AIA.config.context_files = []
  end

  def test_collect_variable_values_empty
    result = @session.send(:collect_variable_values, {})
    assert_equal({}, result)
  end

  def test_collect_variable_values_nil
    result = @session.send(:collect_variable_values, nil)
    assert_equal({}, result)
  end
end
