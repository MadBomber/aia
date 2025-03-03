# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tempfile"

class FullIntegrationTest < Minitest::Test
  def setup
    # Skip all tests if credentials aren't available
    skip "No OpenAI credentials available for integration test" unless ENV["OPENAI_API_KEY"]
    
    # Create temporary directories for prompts and roles
    @prompts_dir = Dir.mktmpdir("prompts")
    @roles_dir = Dir.mktmpdir("roles")
    
    # Create a test prompt file
    File.write(File.join(@prompts_dir, "test_prompt.txt"), "Say hello world in one sentence.")
    
    # Configure PromptManager
    PromptManager.config do |c|
      c.prompts_dir = @prompts_dir
    end
    
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
  end
  
  def teardown
    # Clean up temporary directories
    FileUtils.remove_entry @prompts_dir
    FileUtils.remove_entry @roles_dir
  end
  
  def test_full_integration
    # This test runs through the entire flow from prompt to AI response
    
    # Initialize components
    prompt_handler = AIA::PromptHandler.new(@config)
    client = AIA::AIClientAdapter.new(@config)
    session = AIA::Session.new(@config, prompt_handler, client)
    
    # Capture stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    
    # Run the session
    session.start
    
    # Get the output
    output = $stdout.string
    $stdout = original_stdout
    
    # Verify the output contains a greeting
    refute_empty output
    assert_match(/[Hh]ello/, output)
  end
end
