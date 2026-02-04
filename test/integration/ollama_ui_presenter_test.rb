# test/integration/ollama_ui_presenter_test.rb
#
# Integration tests for UIPresenter using real LLM responses from Ollama.
# Exercises: format_chat_response, display_ai_response, display_token_metrics,
# display_multi_model_metrics, with_spinner, and calculate_cost.

require_relative 'ollama_test_helper'
require 'stringio'
require 'tempfile'

class OllamaUIPresenterTest < Minitest::Test
  include OllamaTestHelper

  def setup
    setup_ollama_single_model
    @ui = AIA::UIPresenter.new
  end

  def test_format_chat_response_with_string
    output = StringIO.new
    @ui.format_chat_response('Hello world', output)
    assert output.string.include?('Hello world')
  end

  def test_format_chat_response_with_code_block
    code_response = "Here is code:\n```ruby\nputs 'hello'\n```\nDone."
    output = StringIO.new
    @ui.format_chat_response(code_response, output)
    result = output.string
    assert result.include?('```ruby')
    assert result.include?("puts 'hello'")
    assert result.include?('Done.')
  end

  def test_format_chat_response_with_real_llm_response
    response = AIA.client.chat('Write a one-line Ruby hello world program')
    output = StringIO.new
    @ui.format_chat_response(response, output)
    refute_empty output.string
  end

  def test_display_ai_response_prints_to_stdout
    AIA.config.output.file = nil
    assert_output(/AI:/) do
      @ui.display_ai_response('Test output')
    end
  end

  def test_display_ai_response_writes_to_file
    Tempfile.create(['ui_test', '.md']) do |f|
      AIA.config.output.file = f.path

      # Capture stdout too since display_ai_response writes to both
      assert_output(/AI:/) do
        @ui.display_ai_response('File response test')
      end

      content = File.read(f.path)
      assert content.include?('File response test')
    end
  ensure
    AIA.config.output.file = nil
  end

  def test_display_thinking_animation
    assert_output(/Processing/) do
      @ui.display_thinking_animation
    end
  end

  def test_display_separator
    assert_output(/.+/) do
      @ui.display_separator
    end
  end

  def test_display_chat_end
    assert_output(/Chat session ended/) do
      @ui.display_chat_end
    end
  end

  def test_display_info
    assert_output(/Hello info/) do
      @ui.display_info('Hello info')
    end
  end

  def test_with_spinner_non_verbose
    AIA.config.flags.verbose = false
    result = @ui.with_spinner('Test') { 42 }
    assert_equal 42, result
  end

  def test_with_spinner_verbose
    AIA.config.flags.verbose = true
    result = @ui.with_spinner('Test', 'OP') { 'done' }
    assert_equal 'done', result
  ensure
    AIA.config.flags.verbose = false
  end

  def test_display_token_metrics_nil
    # Should handle nil gracefully
    assert_output('') do
      @ui.display_token_metrics(nil)
    end
  end

  def test_display_token_metrics_basic
    AIA.config.flags.cost = false
    metrics = { model_id: 'gpt-oss:latest', input_tokens: 50, output_tokens: 100 }
    assert_output(/Input tokens:.*50/) do
      @ui.display_token_metrics(metrics)
    end
  end

  def test_display_multi_model_metrics_empty
    assert_output('') do
      @ui.display_multi_model_metrics(nil)
    end
    assert_output('') do
      @ui.display_multi_model_metrics([])
    end
  end

  def test_display_multi_model_metrics_basic
    AIA.config.flags.cost = false
    metrics_list = [
      { model_id: 'model_a', display_name: 'model_a', input_tokens: 10, output_tokens: 20 },
      { model_id: 'model_b', display_name: 'model_b', input_tokens: 30, output_tokens: 40 }
    ]
    assert_output(/TOTAL/) do
      @ui.display_multi_model_metrics(metrics_list)
    end
  end

  def test_calculate_cost_missing_data
    result = @ui.send(:calculate_cost, { model_id: nil, input_tokens: nil, output_tokens: nil })
    refute result[:available]
  end
end
