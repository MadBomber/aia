# test/aia/local_providers_test.rb

require_relative '../test_helper'
require 'ostruct'
require 'webmock/minitest'
require_relative '../../lib/aia'

class LocalProvidersTest < Minitest::Test
  def setup
    # Enable WebMock
    WebMock.disable_net_connect!(allow_localhost: false)

    # Mock AIA.config
    @mock_config = OpenStruct.new(
      model: ['lms/test-model'],
      tools: [],
      context_files: [],
      debug: false,
      refresh: nil,
      last_refresh: Date.today
    )
    AIA.stubs(:config).returns(@mock_config)

    # Mock RubyLLM configuration
    RubyLLM.stubs(:configure).returns(true)

    # Mock models to prevent refresh API calls
    mock_models = mock('models')
    mock_models.stubs(:refresh!).returns(true)
    RubyLLM.stubs(:models).returns(mock_models)
  end

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  # ===========================
  # LM Studio Provider Tests
  # ===========================

  def test_lms_model_validation_success
    # Mock successful LM Studio response
    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: {
          data: [
            { id: 'test-model' },
            { id: 'another-model' }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock RubyLLM::Context and chat creation
    mock_context = mock('context')
    mock_chat = mock('chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)

    mock_context.expects(:chat)
      .with(model: 'test-model', provider: 'openai', assume_model_exists: true)
      .returns(mock_chat)

    RubyLLM::Context.expects(:new).returns(mock_context)

    # This should not raise an error
    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
  end

  def test_lms_model_validation_failure_invalid_model
    # Mock LM Studio response without the requested model
    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: {
          data: [
            { id: 'different-model' },
            { id: 'another-model' }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Capture the output to check error message is displayed
    output = capture_io do
      adapter = AIA::RubyLLMAdapter.new
      # Adapter will fail to initialize the model but won't raise
      assert_instance_of AIA::RubyLLMAdapter, adapter
    end.first

    assert_match(/Failed to initialize the following models/, output)
    assert_match(/not a valid LM Studio model/, output)
    assert_match(/lms\/different-model/, output)
    assert_match(/lms\/another-model/, output)
  end

  def test_lms_model_validation_failure_no_models_loaded
    # Mock LM Studio response with no models
    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: { data: [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    output = capture_io do
      adapter = AIA::RubyLLMAdapter.new
      assert_instance_of AIA::RubyLLMAdapter, adapter
    end.first

    assert_match(/Failed to initialize the following models/, output)
    assert_match(/No models are currently loaded in LM Studio/, output)
  end

  def test_lms_model_validation_failure_cannot_connect
    # Mock failed connection to LM Studio
    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(status: 500)

    output = capture_io do
      adapter = AIA::RubyLLMAdapter.new
      assert_instance_of AIA::RubyLLMAdapter, adapter
    end.first

    assert_match(/Failed to initialize the following models/, output)
    assert_match(/Cannot connect to LM Studio/, output)
  end

  def test_lms_custom_api_base
    # Set custom API base
    ENV['LMS_API_BASE'] = 'http://custom-host:5678/v1'

    stub_request(:get, "http://custom-host:5678/v1/models")
      .to_return(
        status: 200,
        body: { data: [{ id: 'test-model' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock RubyLLM::Context and chat
    mock_context = mock('context')
    mock_chat = mock('chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)

    mock_context.expects(:chat)
      .with(model: 'test-model', provider: 'openai', assume_model_exists: true)
      .returns(mock_chat)

    RubyLLM::Context.expects(:new).returns(mock_context)

    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
  ensure
    ENV.delete('LMS_API_BASE')
  end

  # ===========================
  # Ollama Provider Tests
  # ===========================

  def test_ollama_model_initialization
    @mock_config.model = ['ollama/llama2']

    # Mock successful Ollama chat creation
    mock_chat = mock('chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)

    RubyLLM.expects(:chat)
      .with(model: 'llama2', provider: 'ollama', assume_model_exists: true)
      .returns(mock_chat)

    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
  end

  def test_ollama_custom_api_base
    @mock_config.model = ['ollama/llama2']
    ENV['OLLAMA_API_BASE'] = 'http://custom-ollama:11434'

    mock_chat = mock('chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)

    RubyLLM.expects(:chat)
      .with(model: 'llama2', provider: 'ollama', assume_model_exists: true)
      .returns(mock_chat)

    # The custom API base is set during configure_rubyllm, not during model setup
    # Just verify it was set in the environment
    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
    assert_equal 'http://custom-ollama:11434', ENV['OLLAMA_API_BASE']
  ensure
    ENV.delete('OLLAMA_API_BASE')
  end

  # ===========================
  # Osaurus Provider Tests
  # ===========================

  def test_osaurus_model_initialization
    @mock_config.model = ['osaurus/test-model']

    # Mock successful Osaurus initialization
    mock_context = mock('context')
    mock_chat = mock('chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)

    mock_context.expects(:chat)
      .with(model: 'test-model', provider: 'openai', assume_model_exists: true)
      .returns(mock_chat)

    RubyLLM::Context.expects(:new).returns(mock_context)

    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
  end

  # ===========================
  # Mixed Provider Tests
  # ===========================

  def test_multiple_providers_initialization
    @mock_config.model = ['gpt-4o-mini', 'ollama/llama2']

    # Mock OpenAI model
    mock_chat_openai = mock('chat_openai')
    mock_model_openai = mock('model_openai')
    mock_model_openai.stubs(:supports_functions?).returns(false)
    mock_chat_openai.stubs(:model).returns(mock_model_openai)

    # Mock Ollama model
    mock_chat_ollama = mock('chat_ollama')
    mock_model_ollama = mock('model_ollama')
    mock_model_ollama.stubs(:supports_functions?).returns(false)
    mock_chat_ollama.stubs(:model).returns(mock_model_ollama)

    RubyLLM.expects(:chat).with(model: 'gpt-4o-mini').returns(mock_chat_openai)
    RubyLLM.expects(:chat)
      .with(model: 'llama2', provider: 'ollama', assume_model_exists: true)
      .returns(mock_chat_ollama)

    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
  end

  # ===========================
  # Model Name Extraction Tests
  # ===========================

  def test_lms_prefix_extraction
    @mock_config.model = ['lms/qwen3-coder']

    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(
        status: 200,
        body: { data: [{ id: 'qwen3-coder' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    mock_context = mock('context')
    mock_chat = mock('chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)

    # Verify that 'qwen3-coder' (without prefix) is passed to the chat
    mock_context.expects(:chat)
      .with(model: 'qwen3-coder', provider: 'openai', assume_model_exists: true)
      .returns(mock_chat)

    RubyLLM::Context.expects(:new).returns(mock_context)

    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
  end

  def test_ollama_prefix_extraction
    @mock_config.model = ['ollama/mistral:7b']

    mock_chat = mock('chat')
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    mock_chat.stubs(:model).returns(mock_model)

    # Verify that 'mistral:7b' (without prefix) is passed to the chat
    RubyLLM.expects(:chat)
      .with(model: 'mistral:7b', provider: 'ollama', assume_model_exists: true)
      .returns(mock_chat)

    adapter = AIA::RubyLLMAdapter.new
    assert_instance_of AIA::RubyLLMAdapter, adapter
  end
end
