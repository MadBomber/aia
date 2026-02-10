# frozen_string_literal: true

require_relative '../../test_helper'

class MultiModelChatTest < Minitest::Test
  # --- MultiModelResponse ---

  def test_multi_model_response_class_exists
    assert_kind_of Class, AIA::Adapter::MultiModelChat::MultiModelResponse
  end

  def test_multi_model_response_from_adapter_namespace
    # Backward compatibility: accessible from RubyLLMAdapter
    assert_equal AIA::Adapter::MultiModelChat::MultiModelResponse,
                 AIA::RubyLLMAdapter::MultiModelResponse
  end

  def test_multi_model_response_stores_content_and_metrics
    metrics = [{ model_id: 'gpt-4o', input_tokens: 10, output_tokens: 20 }]
    response = AIA::Adapter::MultiModelChat::MultiModelResponse.new('hello', metrics)

    assert_equal 'hello', response.content
    assert_equal metrics, response.metrics_list
  end

  def test_multi_model_response_is_multi_model
    response = AIA::Adapter::MultiModelChat::MultiModelResponse.new('', [])
    assert response.multi_model?
  end

  # --- format_model_display_name ---

  def test_format_display_name_with_simple_model
    adapter = build_adapter_with_models

    spec = { model: 'gpt-4o', instance: 1, role: nil }
    result = adapter.format_model_display_name(spec)
    assert_equal 'gpt-4o', result
  end

  def test_format_display_name_with_instance_number
    adapter = build_adapter_with_models

    spec = { model: 'gpt-4o', instance: 2, role: nil }
    result = adapter.format_model_display_name(spec)
    assert_equal 'gpt-4o #2', result
  end

  def test_format_display_name_with_role
    adapter = build_adapter_with_models

    spec = { model: 'gpt-4o', instance: 1, role: 'analyst' }
    result = adapter.format_model_display_name(spec)
    assert_equal 'gpt-4o (analyst)', result
  end

  def test_format_display_name_with_instance_and_role
    adapter = build_adapter_with_models

    spec = { model: 'gpt-4o', instance: 3, role: 'reviewer' }
    result = adapter.format_model_display_name(spec)
    assert_equal 'gpt-4o #3 (reviewer)', result
  end

  def test_format_display_name_returns_non_hash_as_is
    adapter = build_adapter_with_models

    result = adapter.format_model_display_name('just a string')
    assert_equal 'just a string', result
  end

  # --- should_use_consensus_mode? ---

  def test_consensus_mode_enabled
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(consensus: true)
    ))

    adapter = build_adapter_with_models
    assert adapter.should_use_consensus_mode?
  end

  def test_consensus_mode_disabled
    AIA.stubs(:config).returns(OpenStruct.new(
      flags: OpenStruct.new(consensus: false)
    ))

    adapter = build_adapter_with_models
    refute adapter.should_use_consensus_mode?
  end

  # --- build_consensus_prompt ---

  def test_build_consensus_prompt_includes_all_model_responses
    adapter = build_adapter_with_models

    mock_result_a = mock('result_a')
    mock_result_a.stubs(:respond_to?).with(:content).returns(true)
    mock_result_a.stubs(:content).returns('Response from A')

    mock_result_b = mock('result_b')
    mock_result_b.stubs(:respond_to?).with(:content).returns(true)
    mock_result_b.stubs(:content).returns('Response from B')

    results = { 'model-a' => mock_result_a, 'model-b' => mock_result_b }
    prompt = adapter.build_consensus_prompt(results)

    assert_includes prompt, 'consensus response'
    assert_includes prompt, 'model-a:'
    assert_includes prompt, 'Response from A'
    assert_includes prompt, 'model-b:'
    assert_includes prompt, 'Response from B'
  end

  def test_build_consensus_prompt_skips_error_results
    adapter = build_adapter_with_models

    mock_result = mock('result')
    mock_result.stubs(:respond_to?).with(:content).returns(false)
    mock_result.stubs(:to_s).returns('Error with model-a: connection failed')

    results = { 'model-a' => mock_result }
    prompt = adapter.build_consensus_prompt(results)

    refute_includes prompt, 'Error with model-a'
  end

  # --- format_individual_responses ---

  def test_format_individual_responses_without_metrics
    adapter = build_adapter_with_models

    mock_result = mock('result')
    mock_result.stubs(:respond_to?).with(:input_tokens).returns(false)
    mock_result.stubs(:respond_to?).with(:output_tokens).returns(false)
    mock_result.stubs(:respond_to?).with(:content).returns(true)
    mock_result.stubs(:content).returns('Hello world')

    results = { 'gpt-4o' => mock_result }
    output = adapter.format_individual_responses(results)

    assert_kind_of String, output
    assert_includes output, 'from: gpt-4o'
    assert_includes output, 'Hello world'
  end

  def test_format_individual_responses_with_metrics
    adapter = build_adapter_with_models

    mock_result = mock('result')
    mock_result.stubs(:respond_to?).with(:input_tokens).returns(true)
    mock_result.stubs(:respond_to?).with(:output_tokens).returns(true)
    mock_result.stubs(:input_tokens).returns(100)
    mock_result.stubs(:output_tokens).returns(50)
    mock_result.stubs(:respond_to?).with(:content).returns(true)
    mock_result.stubs(:content).returns('Response with metrics')

    results = { 'gpt-4o' => mock_result }
    output = adapter.format_individual_responses(results)

    assert_kind_of AIA::Adapter::MultiModelChat::MultiModelResponse, output
    assert output.multi_model?
    assert_includes output.content, 'Response with metrics'
    assert_equal 1, output.metrics_list.size
  end

  # --- prepend_role_to_conversation ---

  def test_prepend_role_to_conversation
    adapter = build_adapter_with_models

    conversation = [
      { role: 'system', content: 'system msg' },
      { role: 'user', content: 'user query' }
    ]

    result = adapter.prepend_role_to_conversation(conversation, 'You are a Ruby expert.')

    # Role is prepended to the first user message (index 1), not the system message
    assert_equal 'You are a Ruby expert.', result[1][:content].split("\n\n").first
    assert_includes result[1][:content], 'user query'
    # Original should be unchanged
    assert_equal 'user query', conversation[1][:content]
  end

  def test_prepend_role_to_conversation_with_no_user_message
    adapter = build_adapter_with_models

    conversation = [
      { role: 'system', content: 'system msg' }
    ]

    result = adapter.prepend_role_to_conversation(conversation, 'role text')

    # Should return unmodified copy when no user message
    assert_equal 'system msg', result[0][:content]
  end

  def teardown
    super
  end

  private

  def build_adapter_with_models
    adapter = AIA::RubyLLMAdapter.allocate
    adapter.instance_variable_set(:@chats, {})
    adapter.instance_variable_set(:@models, ['gpt-4o'])
    adapter.instance_variable_set(:@contexts, {})
    adapter.instance_variable_set(:@tools, [])
    adapter.instance_variable_set(:@model_specs, [
      { model: 'gpt-4o', instance: 1, role: nil, internal_id: 'gpt-4o' }
    ])
    adapter
  end
end
