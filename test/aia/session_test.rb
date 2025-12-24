require_relative '../test_helper'
require 'tempfile'
require 'ostruct'
require_relative '../../lib/aia'

class SessionTest < Minitest::Test
  def setup
    # Mock AIA module methods BEFORE creating the session
    AIA.stubs(:chat?).returns(false)
    AIA.stubs(:append?).returns(false)
    AIA.stubs(:verbose?).returns(false)
    AIA.stubs(:terse?).returns(false)
    AIA.stubs(:speak?).returns(false)
    AIA.stubs(:debug?).returns(false)
    
    # Mock AIA.config with nested structure (matching new config layout)
    AIA.stubs(:config).returns(OpenStruct.new(
      prompt_id: 'test_prompt',
      context_files: [],
      stdin_content: nil,
      executable_prompt_file: nil,
      pipeline: ['test_prompt'],
      mcp_servers: [],
      tool_names: '',
      prompts: OpenStruct.new(
        dir: '/tmp/test_prompts',
        extname: '.txt',
        roles_prefix: 'roles',
        roles_dir: '/tmp/test_prompts/roles',
        role: nil,
        system_prompt: 'You are a helpful assistant'
      ),
      output: OpenStruct.new(
        file: nil,
        append: false,
        markdown: true,
        history_file: nil
      ),
      flags: OpenStruct.new(
        chat: false,
        fuzzy: false,
        debug: false,
        verbose: false,
        terse: false,
        speak: false
      ),
      llm: OpenStruct.new(
        adapter: 'ruby_llm',
        temperature: 0.7,
        max_tokens: 2048
      ),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      tools: OpenStruct.new(
        paths: [],
        allowed: nil,
        rejected: nil
      ),
      audio: OpenStruct.new(
        voice: 'alloy',
        speak_command: 'afplay',
        speech_model: 'tts-1'
      ),
      registry: OpenStruct.new(
        refresh: 7,
        last_refresh: nil
      )
    ))
    
    @prompt_handler = mock('prompt_handler')
    
    # Mock the get_prompt call that happens during initialization
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:parameters).returns({})
    @prompt_handler.stubs(:get_prompt).returns(mock_prompt)
    
    @session = AIA::Session.new(@prompt_handler)
  end

  def teardown
    # Call super to ensure Mocha cleanup runs properly
    super
  end

  def test_initialization
    refute_nil @session
    assert_instance_of AIA::Session, @session
  end

  def test_should_start_chat_immediately_with_empty_pipeline
    AIA.stubs(:chat?).returns(true)
    AIA.config.pipeline = []
    
    assert @session.send(:should_start_chat_immediately?)
  end

  def test_should_start_chat_immediately_with_empty_prompt_ids
    AIA.stubs(:chat?).returns(true)
    AIA.config.pipeline = ['', nil]
    
    assert @session.send(:should_start_chat_immediately?)
  end

  def test_should_not_start_chat_immediately_when_not_chat_mode
    AIA.stubs(:chat?).returns(false)
    AIA.config.pipeline = []
    
    refute @session.send(:should_start_chat_immediately?)
  end

  def test_should_not_start_chat_immediately_with_valid_prompts
    AIA.stubs(:chat?).returns(true)
    AIA.config.pipeline = ['valid_prompt']
    
    refute @session.send(:should_start_chat_immediately?)
  end

  def test_process_single_prompt_skips_empty_prompt_id
    # This should return early without calling any methods
    @session.send(:process_single_prompt, '')
    @session.send(:process_single_prompt, nil)
    # No assertions needed - we're testing it doesn't crash
  end

  def test_setup_prompt_processing_handles_error
    @prompt_handler.expects(:get_prompt).raises(StandardError.new("Test error"))
    
    # Capture output to verify error message
    output = capture_io do
      result = @session.send(:setup_prompt_processing, 'invalid_prompt')
      assert_nil result
    end
    
    assert_match /Error processing prompt/, output.first
  end

  def test_setup_prompt_processing_success
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:parameters).returns({})
    mock_prompt.stubs(:text).returns('Test prompt')
    mock_prompt.stubs(:text=)
    
    @prompt_handler.expects(:get_prompt).with('test_prompt', nil).returns(mock_prompt)
    
    # Mock the include_context_flag
    @session.instance_variable_set(:@include_context_flag, false)
    
    result = @session.send(:setup_prompt_processing, 'test_prompt')
    assert_equal mock_prompt, result
  end

  def test_finalize_prompt_text_basic
    mock_prompt = mock('prompt')
    mock_prompt.expects(:to_s).returns('Test prompt text')
    
    # Set include_context_flag to false to avoid context file processing
    @session.instance_variable_set(:@include_context_flag, false)
    
    result = @session.send(:finalize_prompt_text, mock_prompt)
    assert_equal 'Test prompt text', result
  end

  def test_finalize_prompt_text_with_context_files
    mock_prompt = mock('prompt')
    mock_prompt.expects(:to_s).returns('Test prompt text')
    
    # Set include_context_flag to true and add context files
    @session.instance_variable_set(:@include_context_flag, true)
    AIA.config.context_files = []
    
    result = @session.send(:finalize_prompt_text, mock_prompt)
    assert_equal 'Test prompt text', result
    
    # Should set flag to false after processing
    refute @session.instance_variable_get(:@include_context_flag)
  end

  def test_update_variable_history_removes_existing_value
    history = ['old_value', 'another_value']
    
    result = @session.send(:update_variable_history, history, 'old_value')
    
    assert_equal ['another_value', 'old_value'], result
  end

  def test_update_variable_history_adds_new_value
    history = ['value1', 'value2']
    
    result = @session.send(:update_variable_history, history, 'new_value')
    
    assert_equal ['value1', 'value2', 'new_value'], result
  end

  def test_update_variable_history_respects_max_size
    # Create a history at max size
    history = (1..AIA::HistoryManager::MAX_VARIABLE_HISTORY).map { |i| "value#{i}" }
    
    result = @session.send(:update_variable_history, history, 'new_value')
    
    assert_equal AIA::HistoryManager::MAX_VARIABLE_HISTORY, result.size
    assert_equal 'new_value', result.last
    refute_includes result, 'value1' # First item should be removed
  end

  def test_enhance_prompt_with_extras_adds_terse_prompt
    mock_text = mock('text')
    mock_text.expects(:<<).with(AIA::Session::TERSE_PROMPT)
    
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:text).returns(mock_text)
    
    AIA.stubs(:terse?).returns(true)
    AIA.config.stdin_content = nil
    AIA.config.executable_prompt_file = nil
    
    @session.send(:enhance_prompt_with_extras, mock_prompt)
  end

  def test_enhance_prompt_with_extras_adds_stdin_content
    mock_text = mock('text')
    mock_text.expects(:<<).with("\n\n").returns(mock_text)
    mock_text.expects(:<<).with('piped content')
    
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:text).returns(mock_text)
    
    AIA.stubs(:terse?).returns(false)
    AIA.config.stdin_content = 'piped content'
    AIA.config.executable_prompt_file = nil
    
    @session.send(:enhance_prompt_with_extras, mock_prompt)
  end

  def test_add_context_files_returns_original_when_no_files
    AIA.config.context_files = nil
    
    result = @session.send(:add_context_files, 'original text')
    assert_equal 'original text', result
    
    AIA.config.context_files = []
    result = @session.send(:add_context_files, 'original text')
    assert_equal 'original text', result
  end

  def test_add_context_files_adds_file_content
    # Create a temporary file
    temp_file = Tempfile.new('test_context')
    temp_file.write('File content here')
    temp_file.close
    
    AIA.config.context_files = [temp_file.path]
    
    result = @session.send(:add_context_files, 'original text')
    expected = "original text\n\nContext:\nFile content here"
    assert_equal expected, result
    
    temp_file.unlink
  end

  def test_setup_prompt_and_history_manager_chat_mode_with_context_files
    AIA.stubs(:chat?).returns(true)
    AIA.config.prompt_id = ''
    AIA.config.context_files = ['file1.txt']
    
    @session.send(:setup_prompt_and_history_manager)
    
    assert_nil @session.instance_variable_get(:@history_manager)
  end

  def test_setup_prompt_and_history_manager_chat_mode_without_context_files
    AIA.stubs(:chat?).returns(true)
    AIA.config.prompt_id = ''
    AIA.config.context_files = []
    
    @session.send(:setup_prompt_and_history_manager)
    
    assert_nil @session.instance_variable_get(:@history_manager)
  end

  def test_initialize_components_creates_all_components
    @session.send(:initialize_components)

    # Note: ContextManager was removed - RubyLLM's Chat maintains conversation history internally
    refute_nil @session.instance_variable_get(:@ui_presenter)
    refute_nil @session.instance_variable_get(:@directive_processor)
    refute_nil @session.instance_variable_get(:@chat_processor)
  end

  def test_setup_output_file_truncates_existing_file
    temp_file = Tempfile.new('test_output')
    temp_file.write('existing content')
    temp_file.close

    AIA.config.output.file = temp_file.path
    AIA.stubs(:append?).returns(false)

    @session.send(:setup_output_file)

    assert_equal '', File.read(temp_file.path)
    temp_file.unlink
  end

  def test_setup_output_file_does_nothing_when_append_mode
    AIA.config.output.file = 'some_file.txt'
    AIA.stubs(:append?).returns(true)

    # Should not try to truncate file
    @session.send(:setup_output_file)
  end

  def test_generate_chat_prompt_id_format
    chat_id = @session.send(:generate_chat_prompt_id)
    
    assert_match /^chat_\d{8}_\d{6}$/, chat_id
  end

  # NOTE: test_handle_clear_directive_returns_nil removed - the //clear directive
  # is now handled by AIA::Directives::Checkpoint module which operates directly
  # on RubyLLM's Chat.@messages

  def test_handle_empty_directive_output_returns_nil
    result = @session.send(:handle_empty_directive_output)
    assert_nil result
  end

  def test_handle_successful_directive_returns_formatted_string
    follow_up_prompt = '//test command'
    directive_output = 'command output'
    
    output = capture_io do
      result = @session.send(:handle_successful_directive, follow_up_prompt, directive_output)
      expected = "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
      assert_equal expected, result
    end
    
    assert_match /command output/, output.first
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

  def test_collect_variable_values_with_history_file
    # Create a temporary prompt file with variables
    temp_prompt_file = Tempfile.new(['test_prompt', '.txt'])
    temp_prompt_file.write('Hello {{name}}, your age is {{age}}.')
    temp_prompt_file.close
    
    # Create a corresponding history file
    history_file = temp_prompt_file.path.sub('.txt', '.json')
    history_data = {
      'name' => ['John', 'Jane'],
      'age' => ['25', '30']
    }
    File.write(history_file, JSON.dump(history_data))
    
    # Mock the prompt handler to return our test prompt
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:parameters).returns({
      'name' => ['John', 'Jane'],
      'age' => ['25', '30']
    })
    mock_prompt.stubs(:text).returns('Hello {{name}}, your age is {{age}}.')
    mock_prompt.stubs(:text=)
    
    @prompt_handler.expects(:get_prompt).returns(mock_prompt)
    
    # Mock HistoryManager to simulate user input
    mock_history_manager = mock('history_manager')
    mock_history_manager.expects(:request_variable_value).with(
      variable_name: 'name',
      history_values: ['John', 'Jane']
    ).returns('Alice')
    mock_history_manager.expects(:request_variable_value).with(
      variable_name: 'age',
      history_values: ['25', '30']
    ).returns('28')
    
    AIA::HistoryManager.expects(:new).with(prompt: mock_prompt).returns(mock_history_manager)
    
    @session.send(:collect_variable_values, mock_prompt)
    
    expected_parameters = {
      'name' => ['John', 'Jane', 'Alice'],
      'age' => ['25', '30', '28']
    }
    assert_equal expected_parameters, mock_prompt.parameters
    
    temp_prompt_file.unlink
    File.unlink(history_file) if File.exist?(history_file)
  end
  
  def test_collect_variable_values_without_history_file
    # This test addresses the issue mentioned in memories where
    # variables are not prompted when no history file exists
    
    # Create a temporary prompt file with variables but no history file
    temp_prompt_file = Tempfile.new(['test_prompt_no_history', '.txt'])
    temp_prompt_file.write('Hello {{name}}, welcome!')
    temp_prompt_file.close
    
    # Mock the prompt handler to return our test prompt
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:parameters).returns({
      'name' => []  # Empty history
    })
    mock_prompt.stubs(:text).returns('Hello {{name}}, welcome!')
    mock_prompt.stubs(:text=)
    
    @prompt_handler.expects(:get_prompt).returns(mock_prompt)
    
    # Mock HistoryManager to simulate user input
    mock_history_manager = mock('history_manager')
    mock_history_manager.expects(:request_variable_value).with(
      variable_name: 'name',
      history_values: []
    ).returns('Bob')
    
    AIA::HistoryManager.expects(:new).with(prompt: mock_prompt).returns(mock_history_manager)
    
    @session.send(:collect_variable_values, mock_prompt)
    
    expected_parameters = {
      'name' => ['Bob']
    }
    assert_equal expected_parameters, mock_prompt.parameters
    
    temp_prompt_file.unlink
  end
  
  def test_collect_variable_values_no_variables
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:parameters).returns({})
    
    # Should not create HistoryManager or request any values
    AIA::HistoryManager.expects(:new).never
    
    @session.send(:collect_variable_values, mock_prompt)
  end
end