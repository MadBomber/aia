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

  def build_pipeline_orchestrator
    AIA::PipelineOrchestrator.new(
      robot:           mock('robot'),
      prompt_handler:  mock('prompt_handler'),
      input_collector: mock('input_collector'),
      ui_presenter:    mock('ui'),
      session_tracker: mock('tracker')
    )
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
    orchestrator = build_pipeline_orchestrator

    AIA.config.context_files = nil
    result = orchestrator.send(:add_context_files, 'original text', AIA.config)
    assert_equal 'original text', result

    AIA.config.context_files = []
    result = orchestrator.send(:add_context_files, 'original text', AIA.config)
    assert_equal 'original text', result
  end

  def test_add_context_files_appends_file_content
    orchestrator = build_pipeline_orchestrator
    temp_file = Tempfile.new('test_context')
    temp_file.write('File content here')
    temp_file.close

    AIA.config.context_files = [temp_file.path]

    result = orchestrator.send(:add_context_files, 'original text', AIA.config)
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

  def test_start_does_not_register_at_exit_hook
    # After the fix, Session#start must NOT call at_exit at all — even on
    # the non-early-return code path that previously contained the hook.
    # We verify this by counting Kernel-level at_exit registrations.
    at_exit_call_count = 0

    # Intercept Kernel-level at_exit calls for the duration of the test
    original_at_exit = Kernel.instance_method(:at_exit)
    Kernel.define_method(:at_exit) { |&blk| at_exit_call_count += 1 }

    begin
      mock_robot = mock('robot')
      AIA::RobotFactory.stubs(:build).returns(mock_robot)
      AIA.stubs(:client=)

      mock_coordinator = mock('coordinator')
      mock_coordinator.stubs(:run)
      mock_coordinator.stubs(:filters).returns({})
      mock_coordinator.stubs(:mcp_manager).returns(nil)
      AIA::StartupCoordinator.stubs(:new).returns(mock_coordinator)
      AIA.stubs(:session_tracker=)

      # Do NOT take the early-return path so we reach the at_exit site
      @session.stubs(:should_start_chat_immediately?).returns(false)

      # Stub PipelineOrchestrator so we skip actual pipeline processing
      mock_pipeline = mock('pipeline_orchestrator')
      mock_pipeline.stubs(:process)
      AIA::PipelineOrchestrator.stubs(:new).returns(mock_pipeline)

      # AIA.chat? is already stubbed to false via AIA.stubs(:chat?)
      # so the chat branch is skipped and execution reaches the at_exit line

      @session.start
      @session.start
    ensure
      # Restore original at_exit
      Kernel.define_method(:at_exit, original_at_exit)
    end

    assert_equal 0, at_exit_call_count,
      "Session#start must not register at_exit; expected 0 calls but got #{at_exit_call_count}"
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

    AIA::VariableInputCollector.expects(:new).returns(mock_hm)

    result = @collector.collect({ 'name' => 'Alice', 'age' => nil })
    assert_equal({ 'name' => 'Bob', 'age' => '30' }, result)
  end
end


class ChatLoopTest < Minitest::Test
  def setup
    @robot = mock('robot')
    @ui_presenter = mock('ui_presenter')
    @directive_processor = mock('directive_processor')

    @chat_loop = AIA::ChatLoop.new(@robot, @ui_presenter, @directive_processor)
  end

  def teardown
    super
  end

  def test_process_directive_returns_formatted_string
    follow_up_prompt = '/test command'
    directive_output = 'command output'

    @directive_processor.stubs(:process).returns(directive_output)
    @directive_processor.stubs(:state_setting?).with(follow_up_prompt).returns(false)

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
    @directive_processor.stubs(:state_setting?).with("/checkpoint test").returns(true)
    @ui_presenter.expects(:display_info).with("Checkpoint created")

    result = @chat_loop.send(:process_directive, "/checkpoint test")
    assert_nil result
  end

  # --- process_initial_context ---

  def test_process_initial_context_skips_when_flag_set
    AIA.stubs(:config).returns(OpenStruct.new(
      context_files: ['some_file.txt'],
      output: OpenStruct.new(file: nil)
    ))

    # Should not call streaming_runner at all
    @chat_loop.send(:process_initial_context, true)
  end

  def test_process_initial_context_skips_when_no_context_files
    AIA.stubs(:config).returns(OpenStruct.new(
      context_files: [],
      output: OpenStruct.new(file: nil)
    ))

    @chat_loop.send(:process_initial_context, false)
  end

  def test_process_initial_context_skips_when_context_files_nil
    AIA.stubs(:config).returns(OpenStruct.new(
      context_files: nil,
      output: OpenStruct.new(file: nil)
    ))

    @chat_loop.send(:process_initial_context, false)
  end

  # --- run_loop exits ---

  def test_run_loop_exits_on_nil_input
    @ui_presenter.stubs(:ask_question).returns(nil)

    @chat_loop.send(:run_loop)
  end

  def test_run_loop_exits_on_exit_command
    @ui_presenter.stubs(:ask_question).returns("exit")

    @chat_loop.send(:run_loop)
  end

  def test_run_loop_exits_on_empty_input
    @ui_presenter.stubs(:ask_question).returns("")

    @chat_loop.send(:run_loop)
  end

  # --- run_loop directives ---

  def test_run_loop_dispatches_directives
    config = OpenStruct.new(
      output: OpenStruct.new(file: nil),
      flags: OpenStruct.new(tokens: false)
    )
    AIA.stubs(:config).returns(config)

    @ui_presenter.stubs(:ask_question).returns("/help", nil)
    @directive_processor.stubs(:directive?).with("/help").returns(true)
    @directive_processor.stubs(:process).returns(nil)
    @directive_processor.stubs(:state_setting?).with("/help").returns(false)

    @chat_loop.send(:run_loop)
  end

  def test_run_loop_shows_unknown_directive
    config = OpenStruct.new(
      output: OpenStruct.new(file: nil),
      flags: OpenStruct.new(tokens: false)
    )
    AIA.stubs(:config).returns(config)

    @ui_presenter.stubs(:ask_question).returns("/unknowndir", nil)
    @directive_processor.stubs(:directive?).with("/unknowndir").returns(false)
    @ui_presenter.expects(:display_info).with { |msg| msg.include?("Unknown directive") }

    @chat_loop.send(:run_loop)
  end

  # --- display_metrics ---

  def test_display_metrics_noop_when_tokens_disabled
    config = OpenStruct.new(
      flags: OpenStruct.new(tokens: false)
    )
    AIA.stubs(:config).returns(config)

    mock_result = mock('result')
    # Should not call display_token_metrics
    @chat_loop.send(:display_metrics, mock_result)
  end

  def test_display_metrics_with_single_result
    config = OpenStruct.new(
      flags: OpenStruct.new(tokens: true),
      models: [OpenStruct.new(name: 'gpt-4o')]
    )
    AIA.stubs(:config).returns(config)

    raw = mock('raw')
    raw.stubs(:respond_to?).with(:input_tokens).returns(true)
    raw.stubs(:input_tokens).returns(100)
    raw.stubs(:output_tokens).returns(50)
    raw.stubs(:respond_to?).with(:model_id).returns(true)
    raw.stubs(:model_id).returns('gpt-4o')
    raw.stubs(:respond_to?).with(:model).returns(false)

    result = mock('result')
    result.stubs(:respond_to?).with(:raw).returns(true)
    result.stubs(:raw).returns(raw)
    result.stubs(:is_a?).returns(false)

    @ui_presenter.expects(:display_token_metrics).with(
      has_entries(model_id: 'gpt-4o', input_tokens: 100, output_tokens: 50)
    )

    @chat_loop.send(:display_metrics, result, elapsed: 1.5)
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
