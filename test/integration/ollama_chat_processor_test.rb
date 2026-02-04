# test/integration/ollama_chat_processor_test.rb
#
# Integration tests for ChatProcessorService using a local Ollama instance.
# Exercises: process_prompt, send_to_client, output_response, determine_operation_type,
# and the metrics extraction code paths.

require_relative 'ollama_test_helper'
require 'tempfile'

class OllamaChatProcessorTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
    @ui = AIA::UIPresenter.new
    @processor = AIA::ChatProcessorService.new(@ui)
  end

  def test_process_prompt_returns_hash
    result = @processor.process_prompt('Say hello')
    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:metrics)
  end

  def test_process_prompt_content_is_string
    result = @processor.process_prompt('What is 1+1? Reply with only the number.')
    assert_kind_of String, result[:content]
    refute_empty result[:content]
  end

  def test_process_prompt_metrics_present
    result = @processor.process_prompt('Say hi')
    metrics = result[:metrics]
    refute_nil metrics, 'Metrics should be present'
    assert metrics[:input_tokens].is_a?(Integer)
    assert metrics[:output_tokens].is_a?(Integer)
    assert metrics[:input_tokens] > 0
    assert metrics[:output_tokens] > 0
  end

  def test_determine_operation_type
    op_type = @processor.send(:determine_operation_type)
    # For a text model, should include "text"
    assert_kind_of String, op_type
    refute_empty op_type
  end

  def test_output_response_to_stdout
    # With output.file = nil, should print to stdout
    AIA.config.output.file = nil
    assert_output(/AI:/) do
      @processor.output_response('Test response')
    end
  end

  def test_output_response_to_file
    Tempfile.create(['aia_test', '.md']) do |f|
      AIA.config.output.file = f.path
      AIA.config.output.append = false

      @processor.output_response('Test file output')

      content = File.read(f.path)
      assert content.include?('Test file output')
    end
  ensure
    AIA.config.output.file = nil
  end

  def test_output_response_appends_to_file
    Tempfile.create(['aia_test', '.md']) do |f|
      File.write(f.path, "Existing content\n")
      AIA.config.output.file = f.path
      AIA.config.output.append = true

      @processor.output_response('Appended output')

      content = File.read(f.path)
      assert content.include?('Existing content')
      assert content.include?('Appended output')
    end
  ensure
    AIA.config.output.file = nil
    AIA.config.output.append = false
  end

  def test_output_response_writes_history
    Tempfile.create(['aia_history', '.log']) do |f|
      AIA.config.output.file = nil
      AIA.config.output.history_file = f.path

      assert_output(/AI:/) do
        @processor.output_response('History test')
      end

      content = File.read(f.path)
      assert content.include?('History test')
      assert content.include?('Response:')
    end
  ensure
    AIA.config.output.history_file = nil
  end

  def test_send_to_client_returns_response
    result = @processor.send(:send_to_client, 'Say hello')
    refute_nil result
    # Should be a RubyLLM response object
    assert result.respond_to?(:content) || result.is_a?(String)
  end
end


class OllamaChatProcessorMultiModelTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_multi_model
    @ui = AIA::UIPresenter.new
    @processor = AIA::ChatProcessorService.new(@ui)
  end

  def test_process_prompt_multi_model
    result = @processor.process_prompt('Say hello')
    assert_kind_of Hash, result
    refute_nil result[:content]
  end

  def test_determine_operation_type_multi
    op_type = @processor.send(:determine_operation_type)
    assert_equal 'MULTI-MODEL PROCESSING', op_type
  end
end
