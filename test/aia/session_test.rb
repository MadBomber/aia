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
        extname: '.md',
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

    @session = AIA::Session.new(@prompt_handler)
  end

  def teardown
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
    @session.send(:process_single_prompt, '')
    @session.send(:process_single_prompt, nil)
  end

  def test_initialize_components_creates_all_components
    @session.send(:initialize_components)

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

    @session.send(:setup_output_file)
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
    temp_file = Tempfile.new('test_context')
    temp_file.write('File content here')
    temp_file.close

    AIA.config.context_files = [temp_file.path]

    result = @session.send(:add_context_files, 'original text')
    expected = "original text\n\nContext:\nFile content here"
    assert_equal expected, result

    temp_file.unlink
  end

  def test_handle_successful_directive_returns_formatted_string
    follow_up_prompt = '/test command'
    directive_output = 'command output'

    output = capture_io do
      result = @session.send(:handle_successful_directive, follow_up_prompt, directive_output)
      expected = "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
      assert_equal expected, result
    end

    assert_match /command output/, output.first
  end

  def test_collect_variable_values_returns_empty_for_nil_params
    result = @session.send(:collect_variable_values, nil)
    assert_equal({}, result)
  end

  def test_collect_variable_values_returns_empty_for_empty_params
    result = @session.send(:collect_variable_values, {})
    assert_equal({}, result)
  end

  def test_collect_variable_values_collects_from_user
    mock_hm = mock('history_manager')
    mock_hm.expects(:request_variable_value).with(
      variable_name: 'name',
      default_value: 'Alice'
    ).returns('Bob')
    mock_hm.expects(:request_variable_value).with(
      variable_name: 'age',
      default_value: nil
    ).returns('30')

    AIA::HistoryManager.expects(:new).returns(mock_hm)

    result = @session.send(:collect_variable_values, { 'name' => 'Alice', 'age' => nil })
    assert_equal({ 'name' => 'Bob', 'age' => '30' }, result)
  end

  def test_build_prompt_text_returns_nil_for_missing_prompt
    @prompt_handler.expects(:fetch_prompt).with('bad_id').raises(StandardError.new("not found"))

    output = capture_io do
      result = @session.send(:build_prompt_text, 'bad_id')
      assert_nil result
    end

    assert_match /Error processing prompt/, output.first
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
end
