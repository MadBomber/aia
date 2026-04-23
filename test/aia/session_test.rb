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

  def test_initialize_components_creates_all_components
    @session.send(:initialize_components)

    refute_nil @session.instance_variable_get(:@ui_presenter)
    refute_nil @session.instance_variable_get(:@directive_processor)
    refute_nil @session.instance_variable_get(:@chat_processor)
    refute_nil @session.instance_variable_get(:@input_collector)
    refute_nil @session.instance_variable_get(:@prompt_pipeline)
    refute_nil @session.instance_variable_get(:@chat_loop)
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
end


class PromptPipelineTest < Minitest::Test
  def setup
    AIA.stubs(:chat?).returns(false)
    AIA.stubs(:append?).returns(false)
    AIA.stubs(:verbose?).returns(false)
    AIA.stubs(:speak?).returns(false)

    AIA.stubs(:config).returns(OpenStruct.new(
      prompt_id: 'test_prompt',
      context_files: [],
      stdin_content: nil,
      pipeline: ['test_prompt'],
      prompts: OpenStruct.new(
        dir: '/tmp/test_prompts',
        extname: '.md',
        roles_prefix: 'roles',
        roles_dir: '/tmp/test_prompts/roles',
        role: nil
      ),
      output: OpenStruct.new(file: nil, append: false),
      flags: OpenStruct.new(chat: false, fuzzy: false, verbose: false, tokens: false),
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      tools: OpenStruct.new(paths: []),
      audio: OpenStruct.new(speech_model: nil)
    ))

    @prompt_handler = mock('prompt_handler')
    @chat_processor = mock('chat_processor')
    @ui_presenter = mock('ui_presenter')
    @input_collector = AIA::InputCollector.new

    @pipeline = AIA::PromptPipeline.new(@prompt_handler, @chat_processor, @ui_presenter, @input_collector)
  end

  def teardown
    super
  end

  def test_process_single_skips_empty_prompt_id
    @pipeline.process_single('')
    @pipeline.process_single(nil)
  end

  def test_add_context_files_returns_original_when_no_files
    AIA.config.context_files = nil

    result = @pipeline.add_context_files('original text')
    assert_equal 'original text', result

    AIA.config.context_files = []
    result = @pipeline.add_context_files('original text')
    assert_equal 'original text', result
  end

  def test_add_context_files_adds_file_content
    temp_file = Tempfile.new('test_context')
    temp_file.write('File content here')
    temp_file.close

    AIA.config.context_files = [temp_file.path]

    result = @pipeline.add_context_files('original text')
    expected = "original text\n\nContext:\nFile content here"
    assert_equal expected, result

    temp_file.unlink
  end

  def test_build_prompt_text_returns_nil_for_missing_prompt
    @prompt_handler.expects(:fetch_prompt).with('bad_id').raises(StandardError.new("not found"))

    stderr_messages = []
    @pipeline.stubs(:warn).with { |msg| stderr_messages << msg; true }

    result = @pipeline.build_prompt_text('bad_id')
    assert_nil result
    assert stderr_messages.any? { |m| m.include?('Error processing prompt') }
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
    @chat_processor = mock('chat_processor')
    @ui_presenter = mock('ui_presenter')
    @directive_processor = mock('directive_processor')

    @chat_loop = AIA::ChatLoop.new(@chat_processor, @ui_presenter, @directive_processor)
  end

  def teardown
    super
  end

  def test_process_skill_context_sends_skill_content_when_skills_configured
    Dir.mktmpdir do |dir|
      skill_file = File.join(dir, 'my-skill.md')
      File.write(skill_file, "---\nname: Test Skill\n---\nSkill body content")

      skills_cfg = OpenStruct.new(dir: dir)
      config = OpenStruct.new(
        prompts: OpenStruct.new(skills: [skill_file]),
        skills: skills_cfg
      )
      AIA.stubs(:config).returns(config)

      @chat_processor.expects(:process_prompt).with("Skill body content").returns("acknowledged")
      @chat_processor.expects(:output_response).with("acknowledged")
      @ui_presenter.expects(:display_separator)

      @chat_loop.send(:process_skill_context)
    end
  end

  def test_process_skill_context_noop_when_no_skills_configured
    config = OpenStruct.new(prompts: OpenStruct.new(skills: []))
    AIA.stubs(:config).returns(config)

    @chat_processor.expects(:process_prompt).never

    @chat_loop.send(:process_skill_context)
  end

  def test_handle_successful_directive_returns_formatted_string
    follow_up_prompt = '/test command'
    directive_output = 'command output'

    output = capture_io do
      result = @chat_loop.send(:handle_successful_directive, follow_up_prompt, directive_output)
      expected = "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
      assert_equal expected, result
    end

    assert_match /command output/, output.first
  end

  def test_parse_multi_model_response_empty_input
    result = @chat_loop.send(:parse_multi_model_response, nil)
    assert_equal({}, result)

    result = @chat_loop.send(:parse_multi_model_response, '')
    assert_equal({}, result)
  end

  def test_parse_multi_model_response_single_model
    response = "from: gpt-4o\nHello there!\n"
    result = @chat_loop.send(:parse_multi_model_response, response)
    assert_equal({ "gpt-4o" => "Hello there!" }, result)
  end

  def test_parse_multi_model_response_multiple_models
    response = "from: gpt-4o\nHello!\n\nfrom: claude-3\nHi!\n"
    result = @chat_loop.send(:parse_multi_model_response, response)
    assert_equal({ "gpt-4o" => "Hello!", "claude-3" => "Hi!" }, result)
  end

  def test_parse_multi_model_response_with_role_and_instance
    response = "from: gpt-4o #2 (assistant)\nHello!\n"
    result = @chat_loop.send(:parse_multi_model_response, response)
    assert_equal({ "gpt-4o#2" => "Hello!" }, result)
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
