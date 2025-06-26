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
    
    # Create config with client reference
    @config = OpenStruct.new(
      speech_model: 'tts-1',
      speak_command: 'say',
      out_file: nil,
      log_file: nil,
      prompt_id: 'test_prompt',
      model: 'gpt-4o-mini',
      client: @mock_client
    )
    AIA.stubs(:config).returns(@config)
    
    @service = AIA::ChatProcessorService.new(@mock_ui_presenter, @mock_directive_processor)
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
    skip "Test requires AiClient class which is not available in test environment"
  end

  def test_process_prompt_with_string_response
    conversation = [{ role: 'user', content: 'Hello' }]
    
    @mock_ui_presenter.expects(:with_spinner).with('Processing', 'text TO text').yields
    @mock_client.expects(:chat).with(conversation).returns('AI response')
    
    result = @service.process_prompt(conversation)
    assert_equal 'AI response', result
  end

  def test_process_prompt_with_object_response
    conversation = [{ role: 'user', content: 'Hello' }]
    mock_response = mock('response')
    mock_response.stubs(:content).returns('AI response content')
    
    @mock_ui_presenter.expects(:with_spinner).with('Processing', 'text TO text').yields
    @mock_client.expects(:chat).with(conversation).returns(mock_response)
    
    result = @service.process_prompt(conversation)
    assert_equal 'AI response content', result
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

  def test_output_response_to_stdout_when_out_file_nil
    @config.out_file = nil
    
    @service.expects(:speak).with('Test response')
    @service.expects(:print).with("\nAI:\n  ")
    @service.expects(:puts).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_to_stdout_when_out_file_is_stdout
    @config.out_file = 'STDOUT'
    
    @service.expects(:speak).with('Test response')
    @service.expects(:print).with("\nAI:\n  ")
    @service.expects(:puts).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_to_file_in_write_mode
    @config.out_file = 'output.txt'
    AIA.stubs(:append?).returns(false)
    
    mock_file = mock('file')
    mock_file.expects(:puts).with('Test response')
    File.expects(:open).with('output.txt', 'w').yields(mock_file)
    
    @service.expects(:speak).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_to_file_in_append_mode
    @config.out_file = 'output.txt'
    AIA.stubs(:append?).returns(true)
    
    mock_file = mock('file')
    mock_file.expects(:puts).with('Test response')
    File.expects(:open).with('output.txt', 'a').yields(mock_file)
    
    @service.expects(:speak).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_output_response_logs_to_log_file
    @config.log_file = 'test.log'
    @config.out_file = nil
    
    # Mock Time.now to return a predictable time
    fixed_time = Time.parse('2025-06-25 17:48:32 -0500')
    Time.stubs(:now).returns(fixed_time)
    
    mock_log_file = mock('log_file')
    mock_log_file.expects(:puts).with("=== #{fixed_time} ===")
    mock_log_file.expects(:puts).with('Prompt: test_prompt')
    mock_log_file.expects(:puts).with('Response: Test response')
    mock_log_file.expects(:puts).with('===')
    
    File.expects(:open).with('test.log', 'a').yields(mock_log_file)
    
    @service.expects(:speak).with('Test response')
    @service.expects(:print).with("\nAI:\n  ")
    @service.expects(:puts).with('Test response')
    
    @service.output_response('Test response')
  end

  def test_determine_operation_type
    operation_type = @service.send(:determine_operation_type)
    assert_equal 'text TO text', operation_type
  end
end