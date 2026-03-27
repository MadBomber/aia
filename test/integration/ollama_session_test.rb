# test/integration/ollama_session_test.rb
#
# Integration tests for Session using a local Ollama instance.
# Tests the non-interactive parts: should_start_chat_immediately?
# and process pipeline infrastructure.

require_relative 'ollama_test_helper'

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

end
