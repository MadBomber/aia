require_relative '../test_helper'
require_relative '../../lib/aia'

class RubyLLMAdapterTest < Minitest::Test
  def setup
    # Mock AIA.config with nested structure to prevent dependency issues
    AIA.stubs(:config).returns(OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      tools: OpenStruct.new(paths: []),
      context_files: [],
      flags: OpenStruct.new(debug: false),
      registry: OpenStruct.new(refresh: nil, last_refresh: Date.today),
      paths: OpenStruct.new(config_file: '/tmp/test_config.yml'),
      mcp_servers: []
    ))
    
    # Mock RubyLLM to prevent actual API calls
    RubyLLM.stubs(:configure).returns(true)
    
    # Mock models to prevent refresh API calls
    mock_models = mock('models')
    mock_models.stubs(:refresh!).returns(true)
    RubyLLM.stubs(:models).returns(mock_models)
    
    # Create a mock chat with model method
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(false)
    
    mock_chat = mock('chat')
    mock_chat.stubs(:model).returns(mock_model)
    
    RubyLLM.stubs(:chat).returns(mock_chat)
    
    @adapter = AIA::RubyLLMAdapter.new
  end

  def teardown
    # Call super to ensure Mocha cleanup runs properly
    super
  end

  def test_initialization
    # Simple test that adapter can be initialized
    assert_instance_of AIA::RubyLLMAdapter, @adapter
  end

  def test_basic_functionality
    # Just test that the adapter exists and has expected methods
    assert_respond_to @adapter, :chat
  end
end