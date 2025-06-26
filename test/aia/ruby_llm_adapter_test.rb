require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class RubyLLMAdapterTest < Minitest::Test
  def setup
    # Clear environment variables that might interfere with tests
    ENV.stubs(:fetch).with('OPENAI_API_KEY', nil).returns(nil)
    ENV.stubs(:fetch).with('OPENAI_ORGANIZATION_ID', nil).returns(nil)
    ENV.stubs(:fetch).with('OPENAI_PROJECT_ID', nil).returns(nil)
    ENV.stubs(:fetch).with('ANTHROPIC_API_KEY', nil).returns(nil)
    ENV.stubs(:fetch).with('GEMINI_API_KEY', nil).returns(nil)
    ENV.stubs(:fetch).with('DEEPSEEK_API_KEY', nil).returns(nil)
    ENV.stubs(:fetch).with('OPENROUTER_API_KEY', nil).returns(nil)
    ENV.stubs(:fetch).with('BEDROCK_ACCESS_KEY_ID', nil).returns(nil)
    ENV.stubs(:fetch).with('BEDROCK_SECRET_ACCESS_KEY', nil).returns(nil)
    ENV.stubs(:fetch).with('BEDROCK_REGION', nil).returns(nil)
    ENV.stubs(:fetch).with('BEDROCK_SESSION_TOKEN', nil).returns(nil)
    ENV.stubs(:fetch).with('OLLAMA_API_BASE', nil).returns(nil)
    ENV.stubs(:fetch).with('OPENAI_API_BASE', nil).returns(nil)
    
    # Mock AIA.config to prevent actual API calls and file operations
    AIA.stubs(:config).returns(OpenStruct.new(
      model: 'gpt-4o-mini',
      transcription_model: 'whisper',
      speech_model: 'tts',
      voice: 'default',
      speak_command: 'say',
      image_size: '512x512',
      image_quality: 'high',
      image_style: 'realistic',
      tool_paths: [],
      context_files: [],
      refresh: 7,
      last_refresh: Date.today,
      config_file: nil
    ))
    
    # Mock RubyLLM to prevent actual API calls
    @mock_chat = mock('chat')
    @mock_model = mock('model')
    @mock_modalities = mock('modalities')
    
    @mock_model.stubs(:supports_functions?).returns(false)
    @mock_model.stubs(:modalities).returns(@mock_modalities)
    @mock_chat.stubs(:model).returns(@mock_model)
    
    # Create a config mock that accepts all the API key settings
    @mock_config = mock('config')
    @mock_config.stubs(:openai_api_key=)
    @mock_config.stubs(:openai_organization_id=)
    @mock_config.stubs(:openai_project_id=)
    @mock_config.stubs(:anthropic_api_key=)
    @mock_config.stubs(:gemini_api_key=)
    @mock_config.stubs(:deepseek_api_key=)
    @mock_config.stubs(:openrouter_api_key=)
    @mock_config.stubs(:bedrock_api_key=)
    @mock_config.stubs(:bedrock_secret_key=)
    @mock_config.stubs(:bedrock_region=)
    @mock_config.stubs(:bedrock_session_token=)
    @mock_config.stubs(:ollama_api_base=)
    @mock_config.stubs(:openai_api_base=)
    @mock_config.stubs(:log_level=)
    
    RubyLLM.stubs(:configure).yields(@mock_config)
    RubyLLM.stubs(:chat).returns(@mock_chat)
    
    # Mock model registry refresh
    mock_models = mock('models')
    mock_models.stubs(:refresh!)
    RubyLLM.stubs(:models).returns(mock_models)
    
    @adapter = AIA::RubyLLMAdapter.new
  end

  def test_initialization
    assert_instance_of AIA::RubyLLMAdapter, @adapter
  end

  def test_configure_rubyllm_sets_api_keys
    config_mock = mock('config')
    
    # Set up expectations for all the API key configurations
    config_mock.expects(:openai_api_key=).with(nil)
    config_mock.expects(:openai_organization_id=).with(nil)
    config_mock.expects(:openai_project_id=).with(nil)
    config_mock.expects(:anthropic_api_key=).with(nil)
    config_mock.expects(:gemini_api_key=).with(nil)
    config_mock.expects(:deepseek_api_key=).with(nil)
    config_mock.expects(:openrouter_api_key=).with(nil)
    config_mock.expects(:bedrock_api_key=).with(nil)
    config_mock.expects(:bedrock_secret_key=).with(nil)
    config_mock.expects(:bedrock_region=).with(nil)
    config_mock.expects(:bedrock_session_token=).with(nil)
    config_mock.expects(:ollama_api_base=).with(nil)
    config_mock.expects(:openai_api_base=).with(nil)
    config_mock.expects(:log_level=).with(:fatal)
    
    RubyLLM.expects(:configure).yields(config_mock)
    
    @adapter.configure_rubyllm
  end

  def test_extract_model_parts_with_provider_and_model
    AIA.config.model = 'openai/gpt-4'
    
    result = @adapter.send(:extract_model_parts)
    
    assert_equal 'openai', result[:provider]
    assert_equal 'gpt-4', result[:model]
  end

  def test_extract_model_parts_with_model_only
    AIA.config.model = 'gpt-4o-mini'
    
    result = @adapter.send(:extract_model_parts)
    
    assert_nil result[:provider]
    assert_equal 'gpt-4o-mini', result[:model]
  end

  def test_extract_model_parts_with_invalid_format
    AIA.config.model = 'invalid/format/too/many/parts'
    
    # Mock STDERR and exit to prevent actual termination
    STDERR.expects(:puts).with("ERROR: malformed model name: invalid/format/too/many/parts")
    @adapter.expects(:exit).with(1)
    
    @adapter.send(:extract_model_parts)
  end

  def test_text_to_text_with_simple_string
    @mock_modalities.stubs(:text_to_text?).returns(true)
    @mock_modalities.stubs(:image_to_text?).returns(false)
    @mock_modalities.stubs(:text_to_image?).returns(false)
    @mock_modalities.stubs(:text_to_audio?).returns(false)
    @mock_modalities.stubs(:audio_to_text?).returns(false)
    
    mock_response = mock('response')
    mock_response.stubs(:content).returns('AI response')
    
    @mock_chat.expects(:ask).with('Hello AI').returns(mock_response)
    
    result = @adapter.chat('Hello AI')
    assert_equal 'AI response', result
  end

  def test_text_to_text_with_context_files
    AIA.config.context_files = ['file1.txt', 'file2.txt']
    
    mock_response = mock('response')
    mock_response.stubs(:content).returns('AI response with context')
    
    @mock_chat.expects(:ask).with('Hello AI', with: ['file1.txt', 'file2.txt']).returns(mock_response)
    
    result = @adapter.send(:text_to_text, 'Hello AI')
    assert_equal 'AI response with context', result
  end

  def test_text_to_text_handles_errors
    mock_response = mock('response')
    @mock_chat.expects(:ask).raises(StandardError.new('API Error'))
    
    result = @adapter.send(:text_to_text, 'Hello AI')
    assert_equal 'API Error', result
  end

  def test_extract_text_prompt_with_string
    result = @adapter.send(:extract_text_prompt, 'Simple string')
    assert_equal 'Simple string', result
  end

  def test_extract_text_prompt_with_hash_text_key
    prompt = { text: 'Text from hash' }
    result = @adapter.send(:extract_text_prompt, prompt)
    assert_equal 'Text from hash', result
  end

  def test_extract_text_prompt_with_hash_content_key
    prompt = { content: 'Content from hash' }
    result = @adapter.send(:extract_text_prompt, prompt)
    assert_equal 'Content from hash', result
  end

  def test_extract_text_prompt_with_other_object
    prompt = OpenStruct.new(value: 'test')
    result = @adapter.send(:extract_text_prompt, prompt)
    assert_equal prompt.to_s, result
  end

  def test_extract_image_path_from_string
    prompt = 'Generate an image called test.jpg'
    result = @adapter.send(:extract_image_path, prompt)
    assert_equal 'test.jpg', result
  end

  def test_extract_image_path_from_hash_with_image_key
    prompt = { image: 'path/to/image.png' }
    result = @adapter.send(:extract_image_path, prompt)
    assert_equal 'path/to/image.png', result
  end

  def test_extract_image_path_from_hash_with_image_path_key
    prompt = { image_path: 'path/to/image.jpeg' }
    result = @adapter.send(:extract_image_path, prompt)
    assert_equal 'path/to/image.jpeg', result
  end

  def test_extract_image_path_returns_nil_when_no_image
    prompt = 'Just text with no image'
    result = @adapter.send(:extract_image_path, prompt)
    assert_nil result
  end

  def test_audio_file_detection
    assert @adapter.send(:audio_file?, 'test.mp3')
    assert @adapter.send(:audio_file?, 'test.wav')
    assert @adapter.send(:audio_file?, 'test.m4a')
    assert @adapter.send(:audio_file?, 'test.flac')
    assert @adapter.send(:audio_file?, 'TEST.MP3')  # case insensitive
    
    refute @adapter.send(:audio_file?, 'test.txt')
    refute @adapter.send(:audio_file?, 'test.jpg')
    refute @adapter.send(:audio_file?, 'test')
  end

  def test_transcribe_calls_chat_ask
    mock_response = mock('response')
    mock_response.stubs(:content).returns('Transcribed text')
    
    @mock_chat.expects(:ask).with('Transcribe this audio', with: 'audio.mp3').returns(mock_response)
    
    result = @adapter.transcribe('audio.mp3')
    assert_equal 'Transcribed text', result
  end

  def test_speak_creates_audio_file
    # Mock file operations
    File.expects(:write).with(regexp_matches(/\d+\.mp3/), 'Mock TTS audio content')
    File.expects(:exist?).returns(true)
    
    # Mock system commands
    @adapter.expects(:system).with('which say > /dev/null 2>&1').returns(true)
    @adapter.expects(:system).with(regexp_matches(/say \d+\.mp3/)).returns(true)
    
    result = @adapter.speak('Hello world')
    assert_match(/Audio generated and saved to: \d+\.mp3/, result)
  end

  def test_speak_handles_errors
    File.expects(:write).raises(StandardError.new('File error'))
    
    result = @adapter.speak('Hello world')
    assert_equal 'Error generating audio: File error', result
  end

  def test_clear_context_reinitializes_chat
    # Mock the chat reinitialization
    RubyLLM.expects(:chat).with(model: 'gpt-4o-mini').returns(@mock_chat)
    
    result = @adapter.clear_context
    assert_equal 'Chat context successfully cleared.', result
  end

  def test_clear_context_handles_errors
    # Mock an error during chat reinitialization
    RubyLLM.expects(:chat).raises(StandardError.new('Chat error'))
    STDERR.expects(:puts).with('ERROR: Chat error')
    @adapter.expects(:exit).with(1)
    
    @adapter.clear_context
  end

  def test_method_missing_delegates_to_chat
    @mock_chat.expects(:respond_to?).with(:some_method).returns(true)
    @mock_chat.expects(:public_send).with(:some_method, 'arg1', 'arg2').returns('result')
    
    result = @adapter.some_method('arg1', 'arg2')
    assert_equal 'result', result
  end

  def test_method_missing_raises_for_unknown_methods
    @mock_chat.expects(:respond_to?).with(:unknown_method).returns(false)
    
    assert_raises(NoMethodError) do
      @adapter.unknown_method
    end
  end

  def test_respond_to_missing_returns_true_for_chat_methods
    @mock_chat.expects(:respond_to?).with(:some_method).returns(true)
    
    assert @adapter.respond_to?(:some_method)
  end

  def test_respond_to_missing_returns_false_for_unknown_methods
    @mock_chat.expects(:respond_to?).with(:unknown_method).returns(false)
    
    refute @adapter.respond_to?(:unknown_method)
  end

  def test_tools_accessor
    # Since tools are set up during initialization and we mocked the tool discovery
    # the tools array should be empty in our test setup
    assert_respond_to @adapter, :tools
  end
  
  def test_extract_model_parts_edge_cases
    # Test with provider but no model - 'openai/' splits to ['openai'] (1 part)
    AIA.config.model = 'openai/'
    result = @adapter.send(:extract_model_parts)
    assert_nil result[:provider]  # 1 part means provider is nil
    assert_equal 'openai', result[:model]  # and the part becomes the model
  end
  
  def test_extract_model_parts_with_invalid_format
    # Test with empty string - should raise error  
    AIA.config.model = ''
    @adapter.expects(:exit).with(1)
    
    # Capture any output to prevent unexpected STDERR output failures
    capture_io do
      @adapter.send(:extract_model_parts)
    end
  end
  
  private
  
  def capture_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
  
  def test_extract_text_prompt_comprehensive
    # Test with nil
    result = @adapter.send(:extract_text_prompt, nil)
    assert_equal '', result
    
    # Test with number
    result = @adapter.send(:extract_text_prompt, 42)
    assert_equal '42', result
    
    # Test with array
    result = @adapter.send(:extract_text_prompt, ['item1', 'item2'])
    assert_instance_of String, result
    
    # Test with complex hash
    complex_hash = { text: 'text_value', content: 'content_value', other: 'other_value' }
    result = @adapter.send(:extract_text_prompt, complex_hash)
    assert_equal 'text_value', result  # text takes precedence
    
    # Test with hash without text or content
    hash_without_text = { description: 'A description', value: 123 }
    result = @adapter.send(:extract_text_prompt, hash_without_text)
    assert_instance_of String, result
  end
  
  def test_extract_image_path_comprehensive
    # Test various image extensions
    extensions = %w[jpg jpeg png gif webp JPG JPEG PNG GIF WEBP]
    extensions.each do |ext|
      prompt = "Generate an image called test.#{ext}"
      result = @adapter.send(:extract_image_path, prompt)
      assert_equal "test.#{ext}", result
    end
    
    # Test with path separators - regex captures filename part
    prompt = 'Save image to /path/to/images/test.jpg'
    result = @adapter.send(:extract_image_path, prompt)
    # The regex captures the filename with word boundaries, so should match
    assert_equal 'path/to/images/test.jpg', result
    
    # Test with multiple images (should return first match)
    prompt = 'Generate test1.jpg and test2.png'
    result = @adapter.send(:extract_image_path, prompt)
    assert_equal 'test1.jpg', result
    
    # Test with non-hash object
    result = @adapter.send(:extract_image_path, OpenStruct.new(value: 'test'))
    assert_nil result
  end
  
  def test_audio_file_detection_comprehensive
    # Test case sensitivity
    assert @adapter.send(:audio_file?, 'FILE.MP3')
    assert @adapter.send(:audio_file?, 'file.Mp3')
    assert @adapter.send(:audio_file?, 'file.mP3')
    
    # Test with paths
    assert @adapter.send(:audio_file?, '/path/to/audio.wav')
    assert @adapter.send(:audio_file?, 'relative/path/audio.m4a')
    
    # Test with various non-audio files
    non_audio = ['file.txt', 'file.doc', 'file.pdf', 'file.mp4', 'file.avi']
    non_audio.each do |file|
      refute @adapter.send(:audio_file?, file), "Should not detect #{file} as audio"
    end
    
    # Test with nil and empty string
    refute @adapter.send(:audio_file?, nil)
    refute @adapter.send(:audio_file?, '')
    
    # Test with file extension only
    refute @adapter.send(:audio_file?, '.mp3')
    assert @adapter.send(:audio_file?, 'a.mp3')
  end
  
  def test_refresh_local_model_registry_logic
    # Test when refresh is needed (last_refresh is old)
    AIA.config.refresh = 7
    AIA.config.last_refresh = Date.today - 10  # 10 days ago
    
    mock_models = mock('models')
    mock_models.expects(:refresh!)
    RubyLLM.stubs(:models).returns(mock_models)
    
    # Expect config update
    AIA.config.expects(:last_refresh=).with(Date.today)
    
    @adapter.refresh_local_model_registry
    
    # Test when refresh is not needed (last_refresh is recent)
    AIA.config.refresh = 7
    AIA.config.last_refresh = Date.today - 3  # 3 days ago
    
    # Should not call refresh!
    mock_models_no_refresh = mock('models')
    mock_models_no_refresh.expects(:refresh!).never
    RubyLLM.stubs(:models).returns(mock_models_no_refresh)
    
    @adapter.refresh_local_model_registry
  end
  
  def test_refresh_with_zero_interval
    # Test when refresh is 0 (always refresh)
    AIA.config.refresh = 0
    AIA.config.last_refresh = Date.today  # Even today should trigger refresh
    
    mock_models = mock('models')
    mock_models.expects(:refresh!)
    RubyLLM.stubs(:models).returns(mock_models)
    
    AIA.config.expects(:last_refresh=).with(Date.today)
    
    @adapter.refresh_local_model_registry
  end
  
  def test_refresh_with_nil_refresh
    # Test when refresh is nil (should refresh)
    AIA.config.refresh = nil
    
    mock_models = mock('models')
    mock_models.expects(:refresh!)
    RubyLLM.stubs(:models).returns(mock_models)
    
    AIA.config.expects(:last_refresh=).with(Date.today)
    
    @adapter.refresh_local_model_registry
  end
  
  def test_clear_context_comprehensive_cleanup
    # Test that all cleanup steps are attempted
    @mock_chat.stubs(:instance_variable_defined?).with(:@messages).returns(true)
    @mock_chat.stubs(:instance_variable_get).with(:@messages).returns(['old', 'messages'])
    @mock_chat.expects(:instance_variable_set).with(:@messages, [])
    
    # Test RubyLLM global state cleanup
    RubyLLM.stubs(:instance_variable_defined?).with(:@chat).returns(true)
    RubyLLM.expects(:instance_variable_set).with(:@chat, nil)
    
    # Test chat recreation
    RubyLLM.expects(:chat).with(model: 'gpt-4o-mini').returns(@mock_chat)
    
    # Test clear_history method call
    @mock_chat.stubs(:respond_to?).with(:clear_history).returns(true)
    @mock_chat.expects(:clear_history)
    
    # Test final verification
    @mock_chat.stubs(:instance_variable_defined?).with(:@messages).returns(true)
    @mock_chat.stubs(:instance_variable_get).with(:@messages).returns([])
    
    result = @adapter.clear_context
    assert_equal 'Chat context successfully cleared.', result
  end
  
  def test_clear_context_error_handling_comprehensive
    # Test error in messages cleanup - should return error message
    @mock_chat.stubs(:instance_variable_defined?).raises(StandardError.new('Variable error'))
    
    result = @adapter.clear_context
    assert_equal 'Error clearing chat context: Variable error', result
    
    # Test error in chat recreation
    @mock_chat.stubs(:instance_variable_defined?).returns(false)
    RubyLLM.expects(:chat).with(model: 'gpt-4o-mini').raises(StandardError.new('Chat creation error'))
    STDERR.expects(:puts).with('ERROR: Chat creation error')
    @adapter.expects(:exit).with(1)
    
    @adapter.clear_context
  end
end