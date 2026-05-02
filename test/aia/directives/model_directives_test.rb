# frozen_string_literal: true

# test/aia/directives/model_directives_test.rb

require_relative '../../test_helper'
require 'ostruct'
require 'stringio'

class ModelDirectivesTest < Minitest::Test
  def setup
    models = [OpenStruct.new(name: 'gpt-4', role: nil, instance: 1, internal_id: 'gpt-4')]
    @mock_config = OpenStruct.new(
      models: models,
      flags: OpenStruct.new(debug: false, verbose: false),
      llm: OpenStruct.new(temperature: 0.7)
    )
    AIA.stubs(:config).returns(@mock_config)

    @instance = AIA::ModelDirectives.new

    @original_stdout = $stdout
    @captured = StringIO.new
    $stdout = @captured
  end

  def teardown
    $stdout = @original_stdout
    super
  end

  # ---------------------------------------------------------------------------
  # format_bytes — private helper accessible via public method
  # ---------------------------------------------------------------------------

  def test_format_bytes_zero
    assert_equal '0 B', @instance.format_bytes(0)
  end

  def test_format_bytes_bytes_range
    assert_equal '512.0 B', @instance.format_bytes(512)
  end

  def test_format_bytes_kilobytes
    assert_equal '1.0 KB', @instance.format_bytes(1024)
    assert_equal '2.5 KB', @instance.format_bytes(2560)
  end

  def test_format_bytes_megabytes
    assert_equal '1.0 MB', @instance.format_bytes(1024 * 1024)
    assert_equal '5.0 MB', @instance.format_bytes(5 * 1024 * 1024)
  end

  def test_format_bytes_gigabytes
    assert_equal '1.0 GB', @instance.format_bytes(1024 ** 3)
    assert_equal '3.5 GB', @instance.format_bytes((3.5 * 1024 ** 3).to_i)
  end

  def test_format_bytes_terabytes
    assert_equal '1.0 TB', @instance.format_bytes(1024 ** 4)
  end

  def test_format_bytes_caps_at_terabytes_for_huge_values
    huge = 5 * 1024 ** 5
    result = @instance.format_bytes(huge)
    assert_match(/\d+\.\d+ TB/, result)
  end

  # ---------------------------------------------------------------------------
  # available_models — routing based on model name prefix
  # ---------------------------------------------------------------------------

  def test_available_models_returns_empty_string
    @instance.stubs(:show_rubyllm_models).with([], [])
    result = @instance.available_models
    assert_equal '', result
  end

  def test_available_models_calls_show_rubyllm_models_for_non_local_provider
    @instance.expects(:show_rubyllm_models).with([], []).once
    @instance.available_models
  end

  def test_available_models_calls_show_local_models_for_ollama
    @mock_config.models = [OpenStruct.new(name: 'ollama/llama2')]
    @instance.expects(:show_local_models).with(['ollama/llama2'], [], []).once
    @instance.available_models
  end

  def test_available_models_calls_show_local_models_for_lms
    @mock_config.models = [OpenStruct.new(name: 'lms/some-model')]
    @instance.expects(:show_local_models).with(['lms/some-model'], [], []).once
    @instance.available_models
  end

  def test_available_models_uses_to_s_when_model_has_no_name_method
    plain_string_model = 'gpt-4'
    @mock_config.models = [plain_string_model]
    @instance.expects(:show_rubyllm_models).with([], []).once
    @instance.available_models
  end

  def test_available_models_aliases_are_defined
    assert_respond_to @instance, :am
    assert_respond_to @instance, :available
    assert_respond_to @instance, :models
    assert_respond_to @instance, :all_models
    assert_respond_to @instance, :llms
  end

  def test_available_models_aliases_point_to_correct_method
    assert_equal :available_models, @instance.method(:am).original_name
    assert_equal :available_models, @instance.method(:available).original_name
    assert_equal :available_models, @instance.method(:models).original_name
    assert_equal :available_models, @instance.method(:all_models).original_name
    assert_equal :available_models, @instance.method(:llms).original_name
  end

  # ---------------------------------------------------------------------------
  # compare — argument parsing and validation
  # ---------------------------------------------------------------------------

  def test_compare_returns_error_on_empty_args
    result = @instance.compare([])
    assert_equal 'Error: No prompt provided for comparison', result
  end

  def test_compare_returns_error_when_no_models_specified
    result = @instance.compare(['my prompt'])
    assert_equal 'Error: No models specified. Use --models model1,model2,model3', result
  end

  def test_compare_returns_error_when_only_models_flag_given
    # --models provided but no prompt token
    result = @instance.compare(['--models', 'gpt-4'])
    assert_equal 'Error: No prompt provided for comparison', result
  end

  def test_compare_calls_rubyllm_for_each_model
    mock_response = OpenStruct.new(content: 'answer')
    mock_chat = mock('chat')
    mock_chat.stubs(:ask).returns(mock_response)

    RubyLLM.expects(:chat).with(model: 'gpt-4').returns(mock_chat)
    RubyLLM.expects(:chat).with(model: 'claude-3').returns(mock_chat)

    @instance.compare(['test prompt', '--models', 'gpt-4,claude-3'])
  end

  def test_compare_returns_empty_string_on_success
    mock_response = OpenStruct.new(content: 'answer')
    mock_chat = mock('chat')
    mock_chat.stubs(:ask).returns(mock_response)
    RubyLLM.stubs(:chat).returns(mock_chat)

    result = @instance.compare(['test prompt', '--models', 'gpt-4'])
    assert_equal '', result
  end

  def test_compare_outputs_comparison_header
    mock_response = OpenStruct.new(content: 'answer')
    mock_chat = mock('chat')
    mock_chat.stubs(:ask).returns(mock_response)
    RubyLLM.stubs(:chat).returns(mock_chat)

    @instance.compare(['hello world', '--models', 'gpt-4'])
    output = @captured.string

    assert_includes output, 'Comparing responses for: hello world'
  end

  def test_compare_handles_model_errors_gracefully
    RubyLLM.stubs(:chat).raises(StandardError, 'API unavailable')

    result = @instance.compare(['test prompt', '--models', 'bad-model'])
    output = @captured.string

    assert_equal '', result
    assert_includes output, 'Error with bad-model: API unavailable'
    assert_includes output, 'Comparison complete!'
  end

  def test_compare_strips_whitespace_from_model_names
    mock_response = OpenStruct.new(content: 'ok')
    mock_chat = mock('chat')
    mock_chat.stubs(:ask).returns(mock_response)

    # The model name should be stripped before being passed to RubyLLM.chat
    RubyLLM.expects(:chat).with(model: 'gpt-4').returns(mock_chat)

    @instance.compare(['prompt', '--models', ' gpt-4 '])
  end

  def test_compare_cmp_alias_exists
    assert_respond_to @instance, :cmp
    assert_equal :compare, @instance.method(:cmp).original_name
  end

  # ---------------------------------------------------------------------------
  # show_rubyllm_models — output formatting with stubbed RubyLLM.models
  # ---------------------------------------------------------------------------

  def build_fake_llm(id: 'gpt-4', provider: 'openai', cw: 128_000, caps: ['chat'],
                     inputs: ['text'], outputs: ['text'], price: 5.0)
    modalities = OpenStruct.new(
      input: inputs,
      output: outputs
    )
    pricing = OpenStruct.new(
      text_tokens: OpenStruct.new(
        standard: OpenStruct.new(
          to_h: { input_per_million: price }
        )
      )
    )
    OpenStruct.new(
      id: id,
      provider: provider,
      context_window: cw,
      capabilities: caps,
      modalities: modalities,
      pricing: pricing
    )
  end

  def stub_rubyllm_models(llms)
    fake_collection = mock('models_collection')
    fake_collection.stubs(:all).returns(llms)
    RubyLLM.stubs(:models).returns(fake_collection)
  end

  def test_show_rubyllm_models_prints_header_without_query
    stub_rubyllm_models([])
    @instance.show_rubyllm_models([], [])
    assert_includes @captured.string, 'Available LLMs:'
  end

  def test_show_rubyllm_models_prints_header_with_query
    stub_rubyllm_models([])
    @instance.show_rubyllm_models(['gpt'], [])
    assert_includes @captured.string, 'Available LLMs for gpt:'
  end

  def test_show_rubyllm_models_lists_each_model
    llm = build_fake_llm(id: 'gpt-4', provider: 'openai', cw: 128_000, price: 5.0,
                         caps: ['chat'], inputs: ['text'], outputs: ['text'])
    stub_rubyllm_models([llm])
    @instance.show_rubyllm_models([], [])
    output = @captured.string
    assert_includes output, '- gpt-4 (openai)'
    assert_includes output, 'cw: 128000'
    assert_includes output, 'mode: text to text'
    assert_includes output, 'caps: chat'
  end

  def test_show_rubyllm_models_prints_count_line
    llm = build_fake_llm
    stub_rubyllm_models([llm])
    @instance.show_rubyllm_models([], [])
    assert_match(/1 LLMs matching your query/, @captured.string)
  end

  def test_show_rubyllm_models_filters_by_positive_term
    llm1 = build_fake_llm(id: 'gpt-4', provider: 'openai')
    llm2 = build_fake_llm(id: 'claude-3', provider: 'anthropic')
    stub_rubyllm_models([llm1, llm2])

    @instance.show_rubyllm_models(['anthropic'], [])
    output = @captured.string

    assert_includes output, 'claude-3'
    refute_includes output, 'gpt-4'
    assert_match(/1 LLMs matching your query/, output)
  end

  def test_show_rubyllm_models_excludes_by_negative_term
    llm1 = build_fake_llm(id: 'gpt-4', provider: 'openai')
    llm2 = build_fake_llm(id: 'claude-3', provider: 'anthropic')
    stub_rubyllm_models([llm1, llm2])

    @instance.show_rubyllm_models([], ['openai'])
    output = @captured.string

    refute_includes output, 'gpt-4'
    assert_includes output, 'claude-3'
    assert_match(/1 LLMs matching your query/, output)
  end

  def test_show_rubyllm_models_positive_and_negative_combined
    llm1 = build_fake_llm(id: 'gpt-4-turbo', provider: 'openai')
    llm2 = build_fake_llm(id: 'gpt-4o', provider: 'openai')
    llm3 = build_fake_llm(id: 'claude-3', provider: 'anthropic')
    stub_rubyllm_models([llm1, llm2, llm3])

    @instance.show_rubyllm_models(['openai'], ['turbo'])
    output = @captured.string

    assert_includes output, 'gpt-4o'
    refute_includes output, 'gpt-4-turbo'
    refute_includes output, 'claude-3'
    assert_match(/1 LLMs matching your query/, output)
  end

  def test_show_rubyllm_models_negative_only_excludes_from_all
    llm1 = build_fake_llm(id: 'gpt-4', provider: 'openai')
    llm2 = build_fake_llm(id: 'claude-3', provider: 'anthropic')
    stub_rubyllm_models([llm1, llm2])

    @instance.show_rubyllm_models([], ['anthropic'])
    output = @captured.string

    assert_includes output, 'gpt-4'
    refute_includes output, 'claude-3'
  end

  def test_show_rubyllm_models_header_includes_excluding_when_negative_terms_present
    stub_rubyllm_models([])
    @instance.show_rubyllm_models([], ['openai'])
    assert_includes @captured.string, 'excluding: openai'
  end

  def test_show_rubyllm_models_splits_comma_separated_single_arg
    llm = build_fake_llm(id: 'gpt-4', provider: 'openai')
    stub_rubyllm_models([llm])

    # A single comma-separated positive arg should be split and used as multiple queries
    @instance.show_rubyllm_models(['gpt-4,openai'], [])
    output = @captured.string

    assert_includes output, 'gpt-4'
  end

  def test_show_rubyllm_models_zero_results_with_no_match
    llm = build_fake_llm(id: 'gpt-4', provider: 'openai')
    stub_rubyllm_models([llm])

    @instance.show_rubyllm_models(['nonexistent-provider-xyz'], [])
    assert_match(/0 LLMs matching your query/, @captured.string)
  end
end
