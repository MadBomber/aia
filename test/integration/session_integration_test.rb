# frozen_string_literal: true

require "test_helper"
require "fileutils"

class AIA::SessionIntegrationTest < Minitest::Test
  def setup
    # Skip all tests if credentials aren't available
    skip "No OpenAI credentials available for integration test" unless ENV["OPENAI_API_KEY"]
    
    # Create temporary directories for prompts and roles
    @prompts_dir = Dir.mktmpdir("prompts")
    @roles_dir = Dir.mktmpdir("roles")
    
    # Create a test prompt file
    File.write(File.join(@prompts_dir, "test_prompt.txt"), "Say hello world in one sentence.")
    
    # Create a next prompt file
    File.write(File.join(@prompts_dir, "next_prompt.txt"), "Summarize what you just said.")
    
    # Create pipeline prompt files
    File.write(File.join(@prompts_dir, "pipeline1.txt"), "List 3 colors.")
    File.write(File.join(@prompts_dir, "pipeline2.txt"), "For each color you listed, name a fruit of that color.")
    
    # Create a context file
    @context_file = Tempfile.new(['context', '.txt'])
    @context_file.write("This is context information.")
    @context_file.close
    
    @config = OpenStruct.new(
      prompt_id: "test_prompt",
      model: "openai/gpt-3.5-turbo",
      prompts_dir: @prompts_dir,
      roles_dir: @roles_dir,
      out_file: nil,
      log_file: nil,
      temperature: 0.7,
      max_tokens: 50
    )
    
    # Configure PromptManager
    PromptManager.config do |c|
      c.prompts_dir = @prompts_dir
    end
    
    @prompt_handler = AIA::PromptHandler.new(@config)
    @client = AIA::AIClientAdapter.new(@config)
  end
  
  def teardown
    # Clean up temporary directories and files
    FileUtils.remove_entry @prompts_dir
    FileUtils.remove_entry @roles_dir
    @context_file.unlink
  end
  
  def test_start_basic_flow
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Capture stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    
    session.start
    
    output = $stdout.string
    $stdout = original_stdout
    
    refute_empty output
    assert_match(/[Hh]ello/, output)
  end
  
  def test_start_with_context_files
    @config.context_files = [@context_file.path]
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Capture stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    
    session.start
    
    output = $stdout.string
    $stdout = original_stdout
    
    refute_empty output
    assert_match(/[Hh]ello/, output)
  end
  
  def test_start_with_next_prompt
    @config.next = "next_prompt"
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Capture stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    
    session.start
    
    output = $stdout.string
    $stdout = original_stdout
    
    refute_empty output
    # Should contain both the hello response and the summary
    assert_match(/[Hh]ello/, output)
    assert_match(/[Ss]ummar/, output)
  end
  
  def test_start_with_pipeline
    @config.pipeline = ["pipeline1", "pipeline2"]
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Capture stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    
    session.start
    
    output = $stdout.string
    $stdout = original_stdout
    
    refute_empty output
    # Should contain hello, colors, and fruits
    assert_match(/[Hh]ello/, output)
    assert_match(/color/, output)
    assert_match(/fruit/, output)
  end
end
