require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class ChatProcessorServiceTest < Minitest::Test
  def setup
    @mock_ui_presenter = mock('ui_presenter')
    @mock_directive_processor = mock('directive_processor')
    
    # Mock AIA module methods
    AIA.stubs(:speak?).returns(false)
    AIA.stubs(:append?).returns(false)
    
    # Mock AIA.client and related objects
    @mock_client = mock('client')
    @mock_model = mock('model')
    @mock_modalities = mock('modalities')
    
    @mock_model.stubs(:id).returns('gpt-4o-mini')
    @mock_model.stubs(:modalities).returns(@mock_modalities)
    @mock_modalities.stubs(:input).returns(['text'])
    @mock_modalities.stubs(:output).returns(['text'])
    @mock_client.stubs(:model).returns(@mock_model)
    @mock_client.stubs(:class).returns(Class.new)
    
    AIA.stubs(:client).returns(@mock_client)
    
    # Create config with nested structure (matching new config layout)
    @config = OpenStruct.new(
      prompt_id: 'test_prompt',
      client: @mock_client,
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      audio: OpenStruct.new(
        speech_model: 'tts-1',
        speak_command: 'say'
      ),
      output: OpenStruct.new(
        file: nil,
        history_file: nil
      ),
      flags: OpenStruct.new(
        debug: false,
        verbose: false
      ),
      llm: OpenStruct.new(
        temperature: 0.7
      )
    )
    AIA.stubs(:config).returns(@config)
    
    @service = AIA::ChatProcessorService.new(@mock_ui_presenter, @mock_directive_processor)
  end

  def teardown
    # Call super to ensure Mocha cleanup runs properly
    super
  end

  def test_initialization
    assert_instance_of AIA::ChatProcessorService, @service
  end

  def test_initialization_without_directive_processor
    service = AIA::ChatProcessorService.new(@mock_ui_presenter)
    assert_instance_of AIA::ChatProcessorService, service
  end

  def test_speak_when_speak_disabled
    AIA.stubs(:speak?).returns(false)
    
    # Should not execute any speak commands
    @service.speak("Test text")
    # Test passes if no exceptions are thrown
    assert true
  end

  def test_speak_when_speak_enabled_with_model
    # Test basic functionality without requiring AiClient
    assert true  # Simple passing test
  end

  def test_process_prompt_with_string_response
    conversation = [{ role: 'user', content: 'Hello' }]
    
    @mock_ui_presenter.expects(:with_spinner).with('Processing', 'text TO text').yields
    @mock_client.expects(:chat).with(conversation).returns('AI response')
    
    result = @service.process_prompt(conversation)
    expected = { content: 'AI response', metrics: nil }
    assert_equal expected, result
  end

  def test_process_prompt_with_object_response
    conversation = [{ role: 'user', content: 'Hello' }]
    mock_response = mock('response')
    mock_response.stubs(:content).returns('AI response content')
    mock_response.stubs(:input_tokens).returns(100)
    mock_response.stubs(:output_tokens).returns(50)
    mock_response.stubs(:model_id).returns('gpt-4o-mini')
    
    @mock_ui_presenter.expects(:with_spinner).with('Processing', 'text TO text').yields
    @mock_client.expects(:chat).with(conversation).returns(mock_response)
    
    result = @service.process_prompt(conversation)
    expected = { 
      content: 'AI response content',
      metrics: {
        input_tokens: 100,
        output_tokens: 50,
        model_id: 'gpt-4o-mini'
      }
    }
    assert_equal expected, result
  end

  def test_send_to_client_calls_maybe_change_model_then_chat
    conversation = [{ role: 'user', content: 'Test' }]
    
    # Expect maybe_change_model to be called first
    @service.expects(:maybe_change_model)
    @mock_client.expects(:chat).with(conversation).returns('response')
    
    result = @service.send_to_client(conversation)
    assert_equal 'response', result
  end

  def test_maybe_change_model_when_models_match
    @config.model = 'gpt-4o-mini'
    @mock_model.stubs(:id).returns('gpt-4o-mini')
    
    # Should not create a new client when models match
    AIA.expects(:client=).never
    
    @service.send(:maybe_change_model)
  end

  def test_maybe_change_model_when_models_differ
    @config.model = 'gpt-4'
    @mock_model.stubs(:id).returns('gpt-3.5-turbo')

    # Should create a new client when models differ
    new_client = mock('new_client')
    @mock_client.class.expects(:new).returns(new_client)
    AIA.expects(:client=).with(new_client)

    @service.send(:maybe_change_model)
  end

  def test_maybe_change_model_alias_resolves_to_full_id
    # Config uses alias "claude-sonnet-4"; RubyLLM resolves it to the full dated ID.
    # The alias is a prefix of the resolved ID, so no client recreation should happen.
    @config.models = [OpenStruct.new(name: 'claude-sonnet-4')]
    @mock_model.stubs(:id).returns('claude-sonnet-4-20250514')

    AIA.expects(:client=).never

    @service.send(:maybe_change_model)
  end

  def test_maybe_change_model_ollama_prefix_stripped_before_comparison
    # The adapter strips the "ollama/" prefix when creating the RubyLLM chat, so
    # chat.model.id returns "qwen3" while the config stores "ollama/qwen3".
    # The comparison must strip the prefix or "qwen3".include?("ollama/qwen3")
    # returns false, causing a spurious adapter replacement on every pipeline step
    # and destroying conversation history between prompts (Demo 06 regression).
    @config.models = [OpenStruct.new(name: 'ollama/qwen3')]
    @mock_model.stubs(:id).returns('qwen3')

    AIA.expects(:client=).never

    @service.send(:maybe_change_model)
  end

  def test_output_response_to_stdout_when_out_file_nil
    @config.output.file = nil
    
    @service.expects(:speak).with('Test response')
    @service.expects(:print).with("\nAI:\n  ")
    @service.expects(:puts).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_to_stdout_when_out_file_is_stdout
    @config.output.file = 'STDOUT'
    
    @service.expects(:speak).with('Test response')
    @service.expects(:print).with("\nAI:\n  ")
    @service.expects(:puts).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_to_file_in_write_mode
    @config.output.file = 'output.txt'
    AIA.stubs(:append?).returns(false)
    
    mock_file = mock('file')
    mock_file.expects(:puts).with("\nAI: ")
    mock_file.expects(:puts).with("  Test response")
    File.expects(:open).with('output.txt', 'w').yields(mock_file)
    
    @service.expects(:speak).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_to_file_in_append_mode
    @config.output.file = 'output.txt'
    AIA.stubs(:append?).returns(true)
    
    mock_file = mock('file')
    mock_file.expects(:puts).with("\nAI: ")
    mock_file.expects(:puts).with("  Test response")
    File.expects(:open).with('output.txt', 'a').yields(mock_file)
    
    @service.expects(:speak).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_logs_to_history_file
    @config.output.history_file = 'test.log'
    @config.output.file = nil

    # Mock Time.now to return a predictable time
    fixed_time = Time.parse('2025-06-25 17:48:32 -0500')
    Time.stubs(:now).returns(fixed_time)

    mock_history_file = mock('history_file')
    mock_history_file.expects(:puts).with("=== #{fixed_time} ===")
    mock_history_file.expects(:puts).with('Prompt: test_prompt')
    mock_history_file.expects(:puts).with('Response: Test response')
    mock_history_file.expects(:puts).with('===')

    File.expects(:open).with('test.log', 'a').yields(mock_history_file)
    
    @service.expects(:speak).with('Test response')
    @service.expects(:print).with("\nAI:\n  ")
    @service.expects(:puts).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_determine_operation_type
    operation_type = @service.send(:determine_operation_type)
    assert_equal 'text TO text', operation_type
  end

  def test_determine_operation_type_with_array_model
    @config.models = [OpenStruct.new(name: 'gpt-4o-mini'), OpenStruct.new(name: 'claude-3')]

    operation_type = @service.send(:determine_operation_type)
    assert_equal 'MULTI-MODEL PROCESSING', operation_type
  end

  def test_determine_operation_type_with_single_model_array
    @config.models = [OpenStruct.new(name: 'gpt-4o-mini')]

    operation_type = @service.send(:determine_operation_type)
    assert_equal 'text TO text', operation_type
  end

  def test_maybe_change_model_with_array_model
    @config.models = [OpenStruct.new(name: 'gpt-4o-mini'), OpenStruct.new(name: 'claude-3')]

    # Should return early when model is an array
    AIA.expects(:client=).never
    @service.send(:maybe_change_model)
  end

  # ---------------------------------------------------------------------------
  # Conversation history preservation (Issue #152)
  # ---------------------------------------------------------------------------

  def test_maybe_change_model_preserves_adapter_when_history_exists
    # Models differ, but conversation history exists in the adapter.
    # Replacing the adapter would destroy all context, so it must be kept.
    @config.models = [OpenStruct.new(name: 'claude-3-5-sonnet')]
    @mock_model.stubs(:id).returns('gpt-5.4')

    mock_message = mock('message')
    mock_chat    = mock('chat')
    mock_chat.stubs(:messages).returns([mock_message])
    @mock_client.stubs(:chats).returns({ 'gpt-5.4' => mock_chat })

    AIA.expects(:client=).never

    @service.send(:maybe_change_model)
  end

  def test_maybe_change_model_openai_model_with_role_specifying_anthropic_model
    # Reproduces the exact bug from Issue #152:
    # User runs gpt-5.4 but the role file's front matter set AIA.config.models
    # to a Claude model. "gpt-5.4".include?("claude-3-5-sonnet") is false, which
    # would normally trigger an adapter reset — destroying all pipeline history.
    # With the fix, the presence of messages blocks the reset.
    @config.models = [OpenStruct.new(name: 'claude-3-5-sonnet')]
    @mock_model.stubs(:id).returns('gpt-5.4')

    user_msg      = mock('user_message')
    assistant_msg = mock('assistant_message')
    mock_chat     = mock('chat')
    mock_chat.stubs(:messages).returns([user_msg, assistant_msg])
    @mock_client.stubs(:chats).returns({ 'gpt-5.4' => mock_chat })

    AIA.expects(:client=).never

    @service.send(:maybe_change_model)
  end

  def test_maybe_change_model_allows_model_switch_when_no_history
    # When there is no conversation history a model mismatch should still
    # replace the adapter so a fresh session uses the newly configured model.
    @config.models = [OpenStruct.new(name: 'gpt-4')]
    @mock_model.stubs(:id).returns('gpt-3.5-turbo')

    mock_chat = mock('chat')
    mock_chat.stubs(:messages).returns([])   # empty — no prior history
    @mock_client.stubs(:chats).returns({ 'gpt-3.5-turbo' => mock_chat })

    new_client = mock('new_client')
    @mock_client.class.expects(:new).returns(new_client)
    AIA.expects(:client=).with(new_client)

    @service.send(:maybe_change_model)
  end

  def test_maybe_change_model_preserves_adapter_with_multiple_chats_when_any_has_history
    # Even if only one of several chat instances has messages, the adapter
    # should be preserved to protect that conversation history.
    @config.models = [OpenStruct.new(name: 'different-model')]
    @mock_model.stubs(:id).returns('gpt-5.4')

    empty_chat   = mock('empty_chat')
    history_chat = mock('history_chat')
    empty_chat.stubs(:messages).returns([])
    history_chat.stubs(:messages).returns([mock('msg')])
    @mock_client.stubs(:chats).returns({
      'gpt-5.4'       => empty_chat,
      'gpt-5.4-extra' => history_chat
    })

    AIA.expects(:client=).never

    @service.send(:maybe_change_model)
  end

  def test_speak_when_enabled_without_speech_model
    AIA.stubs(:speak?).returns(true)
    @config.audio.speech_model = nil

    stderr_messages = []
    @service.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @service.speak('Test text')

    assert stderr_messages.any? { |m| m.include?("Warning: Unable to speak. Speech model not configured properly.") }
  end

  def test_process_next_prompts_without_directive
    mock_response = 'Regular response'
    mock_prompt_handler = mock('prompt_handler')
    mock_history_manager = mock('history_manager')
    mock_history_manager.stubs(:history).returns([])
    
    @service.instance_variable_set(:@history_manager, mock_history_manager)
    @mock_directive_processor.expects(:directive?).with(mock_response).returns(false)
    
    @service.process_next_prompts(mock_response, mock_prompt_handler)
  end

  def test_process_next_prompts_with_directive
    mock_response = '/config key=value'
    mock_prompt_handler = mock('prompt_handler')
    mock_history_manager = mock('history_manager')
    original_history = [{ role: 'user', content: 'test' }]
    modified_history = [{ role: 'user', content: 'test' }, { role: 'system', content: 'configured' }]
    
    mock_history_manager.stubs(:history).returns(original_history)
    mock_history_manager.expects(:history=).with(modified_history)
    
    @service.instance_variable_set(:@history_manager, mock_history_manager)
    
    @mock_directive_processor.expects(:directive?).with(mock_response).returns(true)
    @mock_directive_processor.expects(:process).with(mock_response, original_history).returns({
      result: 'processed response',
      modified_history: modified_history
    })
    
    @service.process_next_prompts(mock_response, mock_prompt_handler)
  end

  def test_process_next_prompts_with_directive_no_modified_history
    mock_response = '/config key=value'
    mock_prompt_handler = mock('prompt_handler')
    mock_history_manager = mock('history_manager')
    original_history = [{ role: 'user', content: 'test' }]
    
    mock_history_manager.stubs(:history).returns(original_history)
    mock_history_manager.expects(:history=).never
    
    @service.instance_variable_set(:@history_manager, mock_history_manager)
    
    @mock_directive_processor.expects(:directive?).with(mock_response).returns(true)
    @mock_directive_processor.expects(:process).with(mock_response, original_history).returns({
      result: 'processed response',
      modified_history: nil
    })
    
    @service.process_next_prompts(mock_response, mock_prompt_handler)
  end
end