# frozen_string_literal: true

require_relative '../../test_helper'
require 'webmock/minitest'

class ChatExecutionTest < Minitest::Test
  def setup
    WebMock.disable_net_connect!(allow_localhost: false)

    @mock_config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini')],
      tools: OpenStruct.new(paths: [], allowed: nil, rejected: nil),
      context_files: [],
      flags: OpenStruct.new(debug: false, no_mcp: true),
      registry: OpenStruct.new(refresh: nil, last_refresh: Date.today),
      paths: OpenStruct.new(config_file: '/tmp/test_config.yml', aia_dir: nil),
      mcp_servers: [],
      require_libs: nil
    )
    AIA.stubs(:config).returns(@mock_config)

    RubyLLM.stubs(:configure).returns(true)

    mock_models = mock('models')
    mock_models.stubs(:refresh!).returns(true)
    RubyLLM.stubs(:models).returns(mock_models)
  end

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
    super
  end

  # --- extract_model_and_provider ---

  def test_extract_ollama_provider
    adapter = build_adapter_allocate

    actual, provider = adapter.extract_model_and_provider('ollama/llama2')
    assert_equal 'llama2', actual
    assert_equal 'ollama', provider
  end

  def test_extract_lms_provider
    adapter = build_adapter_allocate

    actual, provider = adapter.extract_model_and_provider('lms/qwen-coder')
    assert_equal 'qwen-coder', actual
    assert_equal 'openai', provider
  end

  def test_extract_osaurus_provider
    adapter = build_adapter_allocate

    actual, provider = adapter.extract_model_and_provider('osaurus/my-model')
    assert_equal 'my-model', actual
    assert_equal 'openai', provider
  end

  def test_extract_plain_model
    adapter = build_adapter_allocate

    actual, provider = adapter.extract_model_and_provider('gpt-4o')
    assert_equal 'gpt-4o', actual
    assert_nil provider
  end

  # --- create_isolated_context_for_model ---

  def test_creates_context_for_plain_model
    adapter = build_adapter_allocate

    mock_rubyllm_config = mock('rubyllm_config')
    mock_rubyllm_config.stubs(:dup).returns(mock_rubyllm_config)
    RubyLLM.stubs(:config).returns(mock_rubyllm_config)

    mock_context = mock('context')
    RubyLLM::Context.expects(:new).with(mock_rubyllm_config).returns(mock_context)

    result = adapter.create_isolated_context_for_model('gpt-4o')
    assert_equal mock_context, result
  end

  def test_creates_context_for_lms_model_with_custom_base
    adapter = build_adapter_allocate

    mock_rubyllm_config = mock('rubyllm_config')
    mock_rubyllm_config.stubs(:dup).returns(mock_rubyllm_config)
    mock_rubyllm_config.expects(:openai_api_base=).with('http://localhost:1234/v1')
    mock_rubyllm_config.expects(:openai_api_key=).with('dummy')
    RubyLLM.stubs(:config).returns(mock_rubyllm_config)

    mock_context = mock('context')
    RubyLLM::Context.expects(:new).with(mock_rubyllm_config).returns(mock_context)

    result = adapter.create_isolated_context_for_model('lms/test-model')
    assert_equal mock_context, result
  end

  def test_creates_context_for_osaurus_model
    adapter = build_adapter_allocate

    # Use the expected default or whatever ENV provides
    expected_base = ENV.fetch('OSAURUS_API_BASE', 'http://localhost:11434/v1')

    mock_rubyllm_config = mock('rubyllm_config')
    mock_rubyllm_config.stubs(:dup).returns(mock_rubyllm_config)
    mock_rubyllm_config.expects(:openai_api_base=).with(expected_base)
    mock_rubyllm_config.expects(:openai_api_key=).with('dummy')
    RubyLLM.stubs(:config).returns(mock_rubyllm_config)

    mock_context = mock('context')
    RubyLLM::Context.expects(:new).with(mock_rubyllm_config).returns(mock_context)

    result = adapter.create_isolated_context_for_model('osaurus/test-model')
    assert_equal mock_context, result
  end

  # --- chat routing ---

  def test_chat_delegates_to_single_model_for_one_model
    adapter = build_initialized_adapter

    # Should call single_model_chat
    adapter.expects(:single_model_chat).with('hello', 'gpt-4o-mini').returns('response')

    result = adapter.chat('hello')
    assert_equal 'response', result
  end

  def test_chat_delegates_to_multi_model_for_many_models
    adapter = build_initialized_adapter_multi

    adapter.expects(:multi_model_chat).with('hello').returns('multi response')

    result = adapter.chat('hello')
    assert_equal 'multi response', result
  end

  # --- clear_context ---

  def test_clear_context_returns_success_message
    adapter = build_initialized_adapter

    # Need to set up @contexts
    mock_context = mock('context')
    mock_chat = mock('new_chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)
    mock_context.stubs(:chat).returns(mock_chat)

    adapter.instance_variable_set(:@contexts, { 'gpt-4o-mini' => mock_context })

    result = adapter.clear_context
    assert_equal 'Chat context successfully cleared.', result
  end

  def test_clear_context_handles_recreation_failure
    adapter = build_initialized_adapter

    mock_context = mock('context')
    mock_context.stubs(:chat).raises(StandardError, 'recreation failed')

    adapter.instance_variable_set(:@contexts, { 'gpt-4o-mini' => mock_context })

    # The old chat should be reused when recreation fails
    old_chat = adapter.chats['gpt-4o-mini']
    refute_nil old_chat, "Expected adapter to have a chat for 'gpt-4o-mini'"
    old_chat.stubs(:clear_history)
    old_chat.stubs(:respond_to?).with(:clear_history).returns(true)
    old_chat.stubs(:instance_variable_defined?).with(:@messages).returns(true)
    old_chat.stubs(:instance_variable_set)

    # warn can't be captured by capture_io in Ruby 4.0, so verify via stub
    adapter.expects(:warn).with(regexp_matches(/Could not recreate chat/))

    result = adapter.clear_context
    assert_equal 'Chat context successfully cleared.', result
  end

  # --- validate_lms_model! ---

  def test_validate_lms_model_success
    adapter = build_adapter_allocate

    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: { data: [{ id: 'test-model' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Should not raise
    adapter.validate_lms_model!('test-model', 'http://localhost:1234/v1')
  end

  def test_validate_lms_model_not_found
    adapter = build_adapter_allocate

    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: { data: [{ id: 'other-model' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    error = assert_raises(RuntimeError) do
      adapter.validate_lms_model!('missing-model', 'http://localhost:1234/v1')
    end

    assert_match(/not a valid LM Studio model/, error.message)
    assert_match(/lms\/other-model/, error.message)
  end

  def test_validate_lms_model_no_models_loaded
    adapter = build_adapter_allocate

    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: { data: [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    error = assert_raises(RuntimeError) do
      adapter.validate_lms_model!('test-model', 'http://localhost:1234/v1')
    end

    assert_match(/No models are currently loaded/, error.message)
  end

  def test_validate_lms_model_connection_failure
    adapter = build_adapter_allocate

    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(status: 500)

    error = assert_raises(RuntimeError) do
      adapter.validate_lms_model!('test-model', 'http://localhost:1234/v1')
    end

    assert_match(/Cannot connect to LM Studio/, error.message)
  end

  def test_validate_lms_model_invalid_json
    adapter = build_adapter_allocate

    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: 'not json',
        headers: { 'Content-Type' => 'application/json' }
      )

    error = assert_raises(RuntimeError) do
      adapter.validate_lms_model!('test-model', 'http://localhost:1234/v1')
    end

    assert_match(/Invalid response from LM Studio/, error.message)
  end

  private

  def build_adapter_allocate
    adapter = AIA::RubyLLMAdapter.allocate
    adapter.instance_variable_set(:@chats, {})
    adapter.instance_variable_set(:@models, [])
    adapter.instance_variable_set(:@contexts, {})
    adapter.instance_variable_set(:@tools, [])
    adapter.instance_variable_set(:@model_specs, [])
    adapter
  end

  def build_initialized_adapter
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_model.stubs(:modalities).returns(OpenStruct.new(
      text_to_text?: true, image_to_text?: false, text_to_image?: false,
      text_to_audio?: false, audio_to_text?: false
    ))

    mock_chat = mock('chat')
    mock_chat.stubs(:model).returns(mock_model)
    mock_chat.stubs(:respond_to?).returns(false)

    mock_context = mock('context')
    mock_context.stubs(:chat).returns(mock_chat)
    RubyLLM::Context.stubs(:new).returns(mock_context)

    adapter = AIA::RubyLLMAdapter.new
    adapter
  end

  def build_initialized_adapter_multi
    @mock_config.models = [
      OpenStruct.new(name: 'model-a', role: nil, instance: 1, internal_id: 'model-a'),
      OpenStruct.new(name: 'model-b', role: nil, instance: 1, internal_id: 'model-b')
    ]

    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)

    mock_chat_a = mock('chat_a')
    mock_chat_a.stubs(:model).returns(mock_model)
    mock_chat_a.stubs(:respond_to?).returns(false)

    mock_chat_b = mock('chat_b')
    mock_chat_b.stubs(:model).returns(mock_model)
    mock_chat_b.stubs(:respond_to?).returns(false)

    mock_context = mock('context')
    mock_context.stubs(:chat).returns(mock_chat_a, mock_chat_b)
    RubyLLM::Context.stubs(:new).returns(mock_context)

    adapter = AIA::RubyLLMAdapter.new
    adapter
  end
end
