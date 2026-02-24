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
    AIA.stubs(:speak?).returns(false)
    AIA.stubs(:debug?).returns(false)

    # Mock AIA.config with nested structure (matching v2 config layout)
    AIA.stubs(:config).returns(OpenStruct.new(
      prompt_id: 'test_prompt',
      context_files: [],
      stdin_content: nil,
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
        speak: false,
        tokens: false
      ),
      llm: OpenStruct.new(
        temperature: 0.7,
        max_tokens: 2048,
        top_p: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0
      ),
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini')],
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
      ),
      rules: OpenStruct.new(
        dir: nil,
        enabled: false
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

    # Need a mock robot for ChatLoop creation
    mock_robot = mock('robot')
    @session.instance_variable_set(:@robot, mock_robot)

    assert @session.send(:should_start_chat_immediately?)
  end

  def test_should_start_chat_immediately_with_empty_prompt_ids
    AIA.stubs(:chat?).returns(true)
    AIA.config.pipeline = ['', nil]

    mock_robot = mock('robot')
    @session.instance_variable_set(:@robot, mock_robot)

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

    mock_robot = mock('robot')
    @session.instance_variable_set(:@robot, mock_robot)

    refute @session.send(:should_start_chat_immediately?)
  end

  def test_initialize_components_creates_all_v2_components
    @session.send(:initialize_components)

    refute_nil @session.instance_variable_get(:@ui_presenter)
    refute_nil @session.instance_variable_get(:@directive_processor)
    refute_nil @session.instance_variable_get(:@input_collector)
    refute_nil @session.instance_variable_get(:@rule_router)
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

  def test_extract_content_from_robot_result_with_reply
    mock_result = mock('result')
    mock_result.stubs(:reply).returns('Hello from AI')

    content = @session.send(:extract_content, mock_result)
    assert_equal 'Hello from AI', content
  end

  def test_extract_content_from_string
    content = @session.send(:extract_content, 'Plain string response')
    assert_equal 'Plain string response', content
  end

  def test_add_context_files_returns_original_when_no_files
    AIA.config.context_files = nil
    result = @session.send(:add_context_files, 'original text')
    assert_equal 'original text', result

    AIA.config.context_files = []
    result = @session.send(:add_context_files, 'original text')
    assert_equal 'original text', result
  end

  def test_add_context_files_appends_file_content
    temp_file = Tempfile.new('test_context')
    temp_file.write('File content here')
    temp_file.close

    AIA.config.context_files = [temp_file.path]

    result = @session.send(:add_context_files, 'original text')
    assert_includes result, 'original text'
    assert_includes result, 'File content here'

    temp_file.unlink
  end

  def test_output_to_file_writes_content
    temp_file = Tempfile.new('test_output')
    temp_file.close

    AIA.config.output.file = temp_file.path

    @session.send(:output_to_file, 'test response')

    content = File.read(temp_file.path)
    assert_includes content, 'AI: test response'

    temp_file.unlink
  end

  def test_output_to_file_does_nothing_without_file
    AIA.config.output.file = nil
    @session.send(:output_to_file, 'test response')
  end
end


class InputCollectorTest < Minitest::Test
  def setup
    @collector = AIA::InputCollector.new
  end

  def teardown
    super
  end

  def test_collect_returns_empty_for_nil_params
    result = @collector.collect(nil)
    assert_equal({}, result)
  end

  def test_collect_returns_empty_for_empty_params
    result = @collector.collect({})
    assert_equal({}, result)
  end

  def test_collect_collects_from_user
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

    result = @collector.collect({ 'name' => 'Alice', 'age' => nil })
    assert_equal({ 'name' => 'Bob', 'age' => '30' }, result)
  end
end


class ChatLoopTest < Minitest::Test
  def setup
    @robot = mock('robot')
    @ui_presenter = mock('ui_presenter')
    @directive_processor = mock('directive_processor')
    @rule_router = mock('rule_router')

    @chat_loop = AIA::ChatLoop.new(@robot, @ui_presenter, @directive_processor, @rule_router)
  end

  def teardown
    super
  end

  def test_process_directive_returns_formatted_string
    follow_up_prompt = '/test command'
    directive_output = 'command output'

    @directive_processor.stubs(:process).returns(directive_output)

    output = capture_io do
      result = @chat_loop.send(:process_directive, follow_up_prompt)
      expected = "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
      assert_equal expected, result
    end

    assert_match(/command output/, output.first)
  end

  def test_extract_content_from_reply
    mock_result = mock('result')
    mock_result.stubs(:respond_to?).with(:reply).returns(true)
    mock_result.stubs(:reply).returns('AI reply')

    result = @chat_loop.send(:extract_content, mock_result)
    assert_equal 'AI reply', result
  end

  def test_extract_content_from_string
    result = @chat_loop.send(:extract_content, 'plain text')
    assert_equal 'plain text', result
  end

  def test_process_directive_checkpoint_returns_nil
    @directive_processor.stubs(:process).returns("Checkpoint created")
    @ui_presenter.expects(:display_info).with("Checkpoint created")

    result = @chat_loop.send(:process_directive, "/checkpoint test")
    assert_nil result
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
