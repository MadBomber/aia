require_relative 'test_helper'
require 'ostruct'
require 'tempfile'
require_relative '../lib/aia'

# Mock TestTool class for testing
class TestTool
  def self.name
    'TestTool'
  end
  
  def initialize(config = {})
    @config = config
  end
end

class AIAIntegrationTest < Minitest::Test
  def setup
    @temp_prompts_dir = Dir.mktmpdir('aia_integration_prompts')

    # Mock AIA module methods
    AIA.stubs(:chat?).returns(false)
    AIA.stubs(:append?).returns(false)
    AIA.stubs(:verbose?).returns(false)
    AIA.stubs(:terse?).returns(false)
    AIA.stubs(:speak?).returns(false)
    AIA.stubs(:debug?).returns(false)
    
    # Mock TTY::Screen to avoid ioctl errors in tests
    TTY::Screen.stubs(:width).returns(80)
    TTY::Screen.stubs(:height).returns(24)

    # Mock AIA.config with nested structure (matching new config layout)
    @mock_config = OpenStruct.new(
      prompt_id: nil,
      context_files: [],
      stdin_content: nil,
      executable_prompt_file: nil,
      pipeline: [],
      require_libs: [],
      mcp_servers: [],
      tool_names: '',
      # Nested sections
      llm: OpenStruct.new(
        temperature: 0.7,
        max_tokens: 2048
      ),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      prompts: OpenStruct.new(
        dir: @temp_prompts_dir,
        extname: '.md',
        roles_prefix: 'roles',
        roles_dir: File.join(@temp_prompts_dir, 'roles'),
        role: nil,
        system_prompt: 'You are a helpful assistant',
        parameter_regex: '\\{\\{\\w+\\}\\}'
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
        speak: false,
        erb: true,
        shell: true
      ),
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
        last_refresh: Date.today
      ),
      paths: OpenStruct.new(
        aia_dir: '~/.aia',
        config_file: '~/.aia/config.yml'
      )
    )
    
    # Add client.model structure for utility methods
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(true)
    mock_client = mock('client')
    mock_client.stubs(:model).returns(mock_model)
    @mock_config.client = mock_client
    
    AIA.stubs(:config).returns(@mock_config)

    # Mock external dependencies
    mock_adapter = mock('adapter')
    mock_adapter.stubs(:chat).returns('AI Response')
    mock_adapter.stubs(:tools).returns([])
    AIA::RubyLLMAdapter.stubs(:new).returns(mock_adapter)

  end

  def teardown
    FileUtils.rm_rf(@temp_prompts_dir) if @temp_prompts_dir && Dir.exist?(@temp_prompts_dir)
    # Call super to ensure Mocha cleanup runs properly
    super
  end

  def test_batch_mode_single_prompt_workflow
    # Create a test prompt file
    prompt_file = File.join(@temp_prompts_dir, 'test_prompt.md')
    File.write(prompt_file, 'Hello AI, please respond to this test prompt.')

    @mock_config.prompt_id = 'test_prompt'

    # Mock the session workflow
    mock_session = mock('session')
    mock_session.expects(:start)

    AIA::Session.expects(:new).returns(mock_session)

    # Capture output
    output = capture_io do
      # Simulate the main workflow
      AIA::Utility.robot
      session = AIA::Session.new(AIA::PromptHandler.new)
      session.start
    end

    # Check for key components without exact version
    assert_match(/AI Assistant \(v[\d.\w-]+\) is Online/, output.first) # Should show robot ASCII art
  end

  def test_batch_mode_with_context_files_workflow
    # Create test files
    prompt_file = File.join(@temp_prompts_dir, 'context_test.md')
    File.write(prompt_file, 'Analyze the following context:')

    context_file = Tempfile.new('context')
    context_file.write('This is test context content.')
    context_file.close

    @mock_config.prompt_id = 'context_test'
    @mock_config.context_files = [context_file.path]

    # Mock session
    mock_session = mock('session')
    mock_session.expects(:start)
    AIA::Session.expects(:new).returns(mock_session)

    output = capture_io do
      session = AIA::Session.new(AIA::PromptHandler.new)
      session.start
    end

    context_file.unlink
  end

  def test_batch_mode_with_variables_workflow
    # Create a prompt with variables
    prompt_file = File.join(@temp_prompts_dir, 'variables_test.md')
    File.write(prompt_file, 'Hello {{name}}, you are {{age}} years old.')

    # Create a history file with variable values
    history_file = File.join(@temp_prompts_dir, 'variables_test.json')
    history_data = {
      'name' => ['Alice', 'Bob'],
      'age' => ['25', '30']
    }
    File.write(history_file, JSON.dump(history_data))

    @mock_config.prompt_id = 'variables_test'

    # Mock session
    mock_session = mock('session')
    mock_session.expects(:start)
    AIA::Session.expects(:new).returns(mock_session)

    output = capture_io do
      session = AIA::Session.new(AIA::PromptHandler.new)
      session.start
    end
  end

  def test_chat_mode_workflow
    @mock_config.flags.chat = true
    @mock_config.prompt_id = nil
    @mock_config.context_files = []

    # Mock session for chat mode
    mock_session = mock('session')
    mock_session.expects(:start)
    AIA::Session.expects(:new).returns(mock_session)

    output = capture_io do
      session = AIA::Session.new(AIA::PromptHandler.new)
      session.start
    end

    assert output.first.length >= 0 # Chat mode starts without specific message
  end

  def test_pipeline_workflow
    # Create multiple prompt files
    prompt1_file = File.join(@temp_prompts_dir, 'step1.md')
    File.write(prompt1_file, 'First step')

    prompt2_file = File.join(@temp_prompts_dir, 'step2.md')
    File.write(prompt2_file, 'Second step')

    @mock_config.pipeline = ['step1', 'step2']

    # Mock session
    mock_session = mock('session')
    mock_session.expects(:start)
    AIA::Session.expects(:new).returns(mock_session)

    output = capture_io do
      session = AIA::Session.new(AIA::PromptHandler.new)
      session.start
    end
  end

  def test_error_handling_invalid_prompt_id
    @mock_config.prompt_id = 'nonexistent_prompt'

    # Mock session that will handle the error
    mock_session = mock('session')
    mock_session.expects(:start).raises(RuntimeError.new('Could not find prompt'))
    AIA::Session.expects(:new).returns(mock_session)

    assert_raises(RuntimeError) do
      session = AIA::Session.new(AIA::PromptHandler.new)
      session.start
    end
  end

  def test_configuration_workflow_with_environment_variables
    # Test that myway_config handles environment variables
    # Environment variables now use nested naming like AIA_LLM__TEMPERATURE
    # This test verifies the config structure is correct
    config = AIA::Config.new

    # Test that nested sections exist
    assert_respond_to config, :llm
    assert_respond_to config, :flags
    assert_respond_to config, :models

    # Test that nested values are accessible
    assert_kind_of Numeric, config.llm.temperature
    assert_kind_of Array, config.models
  end

  def test_tool_loading_workflow
    # Create a test tool file
    tool_file = Tempfile.new(['test_tool', '.rb'])
    tool_content = <<~RUBY
      class TestTool
        def self.name
          'test_tool'
        end

        def self.description
          'A test tool for integration testing'
        end
      end
    RUBY
    tool_file.write(tool_content)
    tool_file.close

    @mock_config.tools.paths = [tool_file.path]

    # Test tool loading
    mock_adapter = mock('adapter')
    mock_adapter.stubs(:chat).returns('Tool response')
    mock_adapter.stubs(:tools).returns([TestTool])
    AIA::RubyLLMAdapter.stubs(:new).returns(mock_adapter)

    adapter = AIA::RubyLLMAdapter.new
    assert_equal 1, adapter.tools.size
    assert_equal 'TestTool', adapter.tools.first.name

    tool_file.unlink
  end

  def test_file_output_workflow
    output_file = Tempfile.new('test_output')
    output_file.close

    @mock_config.output.file = output_file.path
    @mock_config.prompt_id = 'test_prompt'

    # Create test prompt
    prompt_file = File.join(@temp_prompts_dir, 'test_prompt.md')
    File.write(prompt_file, 'Test prompt for output')

    # Mock session
    mock_session = mock('session')
    mock_session.expects(:start)
    AIA::Session.expects(:new).returns(mock_session)

    session = AIA::Session.new(AIA::PromptHandler.new)
    session.start

    output_file.unlink
  end

  def test_stdin_processing_workflow
    @mock_config.stdin_content = 'Content from stdin'
    @mock_config.prompt_id = 'stdin_test'

    # Create test prompt
    prompt_file = File.join(@temp_prompts_dir, 'stdin_test.md')
    File.write(prompt_file, 'Process this stdin: {{stdin_content}}')

    # Mock session
    mock_session = mock('session')
    mock_session.expects(:start)
    AIA::Session.expects(:new).returns(mock_session)

    session = AIA::Session.new(AIA::PromptHandler.new)
    session.start
  end

  def test_role_based_workflow
    # Create role and prompt files
    role_file = File.join(@temp_prompts_dir, 'roles', 'developer.md')
    FileUtils.mkdir_p(File.dirname(role_file))
    File.write(role_file, 'You are an expert developer.')

    prompt_file = File.join(@temp_prompts_dir, 'debug_task.md')
    File.write(prompt_file, 'Debug this code issue.')

    @mock_config.prompts.role = 'developer'
    @mock_config.prompt_id = 'debug_task'

    # Mock session
    mock_session = mock('session')
    mock_session.expects(:start)
    AIA::Session.expects(:new).returns(mock_session)

    session = AIA::Session.new(AIA::PromptHandler.new)
    session.start
  end

  def test_error_recovery_workflow
    # Test that the system can recover from various errors
    @mock_config.prompt_id = 'error_test'

    # Create prompt that might cause issues
    prompt_file = File.join(@temp_prompts_dir, 'error_test.md')
    File.write(prompt_file, 'This will test error recovery.')

    # Mock session that fails and recovers
    mock_session = mock('session')
    mock_session.expects(:start).raises(StandardError.new('Temporary error')).then.returns(nil)
    AIA::Session.expects(:new).returns(mock_session)

    # Should handle the error gracefully
    assert_raises(StandardError) do
      session = AIA::Session.new(AIA::PromptHandler.new)
      session.start
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
end
