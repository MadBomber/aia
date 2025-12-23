require_relative '../test_helper'
require 'ostruct'
require 'stringio'
require 'reline'
require_relative '../../lib/aia'

class UIPresenterTest < Minitest::Test
  def setup
    @presenter = AIA::UIPresenter.new
    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output
    
    # Mock AIA.config with nested structure
    AIA.stubs(:config).returns(OpenStruct.new(
      output: OpenStruct.new(file: nil),
      flags: OpenStruct.new(verbose: false)
    ))
    
    # Mock AIA.verbose? method
    AIA.stubs(:verbose?).returns(false)
    
    # Mock TTY::Screen.width
    TTY::Screen.stubs(:width).returns(80)
  end

  def teardown
    $stdout = @original_stdout
    # Call super to ensure global Mocha cleanup runs
    super
  end

  def test_initialization
    assert_instance_of AIA::UIPresenter, @presenter
  end

  def test_user_prompt_constant
    assert_equal "Follow up (cntl-D or 'exit' to end) #=> ", AIA::UIPresenter::USER_PROMPT
  end

  def test_display_chat_header
    @presenter.display_chat_header
    
    output = @captured_output.string
    assert_includes output, '═' * 80
    assert_includes output, "\n"
  end

  def test_display_thinking_animation
    @presenter.display_thinking_animation
    
    output = @captured_output.string
    assert_includes output, "⏳ Processing..."
  end

  def test_display_separator
    @presenter.display_separator
    
    output = @captured_output.string
    assert_includes output, '─' * 80
  end

  def test_display_chat_end
    @presenter.display_chat_end
    
    output = @captured_output.string
    assert_includes output, "Chat session ended."
  end

  def test_display_info
    @presenter.display_info("Test message")
    
    output = @captured_output.string
    assert_includes output, "Test message"
  end

  def test_display_ai_response_with_string
    @presenter.display_ai_response("Hello, world!")
    
    output = @captured_output.string
    assert_includes output, "AI:"
    assert_includes output, "   Hello, world!"
  end

  def test_display_ai_response_with_ruby_llm_message
    # Mock RubyLLM::Message
    mock_message = mock('message')
    mock_message.stubs(:is_a?).with(RubyLLM::Message).returns(true)
    mock_message.stubs(:content).returns("Message content")
    
    @presenter.display_ai_response(mock_message)
    
    output = @captured_output.string
    assert_includes output, "AI:"
    assert_includes output, "   Message content"
  end

  def test_display_ai_response_with_out_file
    temp_file = Tempfile.new('test_output')
    AIA.config.output.file = temp_file.path
    
    @presenter.display_ai_response("Test output")
    
    # Check console output
    output = @captured_output.string
    assert_includes output, "AI:"
    assert_includes output, "   Test output"
    
    # Check file output
    file_content = File.read(temp_file.path)
    assert_includes file_content, "AI:"
    assert_includes file_content, "   Test output"
    
    temp_file.close
    temp_file.unlink
  end

  def test_format_chat_response_with_regular_text
    output_buffer = StringIO.new
    @presenter.format_chat_response("Simple text", output_buffer)
    
    assert_equal "   Simple text\n", output_buffer.string
  end

  def test_format_chat_response_with_multiline_text
    output_buffer = StringIO.new
    text = "Line 1\nLine 2\nLine 3"
    @presenter.format_chat_response(text, output_buffer)
    
    expected = "   Line 1\n   Line 2\n   Line 3\n"
    assert_equal expected, output_buffer.string
  end

  def test_format_chat_response_with_code_block
    output_buffer = StringIO.new
    text = "Here's some code:\n```ruby\ndef hello\n  puts 'world'\nend\n```\nThat's it!"
    @presenter.format_chat_response(text, output_buffer)
    
    output = output_buffer.string
    assert_includes output, "   ```ruby"
    assert_includes output, "   def hello"
    assert_includes output, "     puts 'world'"
    assert_includes output, "   end"
    assert_includes output, "   ```"
    assert_includes output, "   That's it!"
  end

  def test_format_chat_response_with_code_block_without_language
    output_buffer = StringIO.new
    text = "```\nsome code\n```"
    @presenter.format_chat_response(text, output_buffer)
    
    output = output_buffer.string
    assert_includes output, "   ```"
    assert_includes output, "   some code"
  end

  def test_format_chat_response_with_ruby_llm_message
    output_buffer = StringIO.new
    mock_message = mock('message')
    mock_message.stubs(:is_a?).with(RubyLLM::Message).returns(true)
    mock_message.stubs(:content).returns("Message content")
    
    @presenter.format_chat_response(mock_message, output_buffer)
    
    assert_equal "   Message content\n", output_buffer.string
  end

  def test_format_chat_response_with_object_responding_to_to_s
    output_buffer = StringIO.new
    mock_object = mock('object')
    mock_object.stubs(:is_a?).with(RubyLLM::Message).returns(false)
    mock_object.stubs(:respond_to?).with(:to_s).returns(true)
    mock_object.stubs(:to_s).returns("Object as string")
    
    @presenter.format_chat_response(mock_object, output_buffer)
    
    assert_equal "   Object as string\n", output_buffer.string
  end

  def test_ask_question_with_normal_input
    # Stub Reline.readline to simulate user input
    Reline.stubs(:readline).returns("user input")
    result = @presenter.ask_question
    assert_equal 'user input', result
  end

  def test_ask_question_with_empty_input
    # Stub Reline.readline to simulate empty input (whitespace)
    Reline.stubs(:readline).returns("   ")
    result = @presenter.ask_question
    assert_equal '   ', result
  end

  def test_ask_question_with_ctrl_d
    # Stub Reline.readline to simulate Ctrl+D (nil return)
    Reline.stubs(:readline).returns(nil)
    result = @presenter.ask_question
    assert_nil result
  end

  def test_ask_question_with_interrupt
    # Stub Reline.readline to simulate Interrupt exception
    Reline.stubs(:readline).raises(Interrupt)
    result = @presenter.ask_question
    assert_equal 'exit', result
    output = @captured_output.string
    assert_includes output, "Chat session interrupted."
  end

  def test_with_spinner_when_not_verbose
    AIA.stubs(:verbose?).returns(false)
    
    result = @presenter.with_spinner("Testing") do
      "operation result"
    end
    
    assert_equal "operation result", result
    # Should not show spinner output when not verbose
  end

  def test_with_spinner_when_verbose
    AIA.stubs(:verbose?).returns(true)
    
    # Mock TTY::Spinner
    mock_spinner = mock('spinner')
    mock_spinner.expects(:auto_spin)
    mock_spinner.expects(:stop)
    TTY::Spinner.expects(:new).with("[:spinner] Testing...", format: :bouncing_ball).returns(mock_spinner)
    
    result = @presenter.with_spinner("Testing") do
      "operation result"
    end
    
    assert_equal "operation result", result
  end

  def test_with_spinner_with_operation_type
    AIA.stubs(:verbose?).returns(true)
    
    # Mock TTY::Spinner
    mock_spinner = mock('spinner')
    mock_spinner.expects(:auto_spin)
    mock_spinner.expects(:stop)
    TTY::Spinner.expects(:new).with("[:spinner] Processing download...", format: :bouncing_ball).returns(mock_spinner)
    
    result = @presenter.with_spinner("Processing", "download") do
      "download complete"
    end
    
    assert_equal "download complete", result
  end

  def test_with_spinner_handles_exceptions
    AIA.stubs(:verbose?).returns(true)
    
    # Mock TTY::Spinner
    mock_spinner = mock('spinner')
    mock_spinner.expects(:auto_spin)
    mock_spinner.expects(:stop)  # Should still stop even if block raises
    TTY::Spinner.expects(:new).returns(mock_spinner)
    
    assert_raises(StandardError) do
      @presenter.with_spinner("Testing") do
        raise StandardError.new("Test error")
      end
    end
  end

  def test_terminal_width_initialization
    # Mock TTY::Screen.width to return a specific value
    TTY::Screen.stubs(:width).returns(120)
    
    presenter = AIA::UIPresenter.new
    presenter.display_chat_header
    
    output = @captured_output.string
    assert_includes output, '═' * 120
  end
end
