# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tempfile"

class AIA::PromptHandlerIntegrationTest < Minitest::Test
  def setup
    # Create temporary directories for prompts and roles
    @prompts_dir = Dir.mktmpdir("prompts")
    @roles_dir = Dir.mktmpdir("roles")
    
    # Create a test prompt file
    File.write(File.join(@prompts_dir, "test_prompt.txt"), "This is a test prompt")
    
    # Create a test role file
    File.write(File.join(@roles_dir, "expert.txt"), "You are an expert")
    
    # Create a test prompt with directives
    directives_content = <<~TEXT
      //config model = openai/gpt-4
      //next next_prompt
      //pipeline prompt1,prompt2
      Normal text
    TEXT
    File.write(File.join(@prompts_dir, "directives_prompt.txt"), directives_content)
    
    # Create a prompt with shell commands
    shell_content = <<~TEXT
      Echo: $(echo hello)
      Date: $(date +%Y)
    TEXT
    File.write(File.join(@prompts_dir, "shell_prompt.txt"), shell_content)
    
    # Create a prompt with ERB
    erb_content = <<~TEXT
      Sum: <%= 1 + 2 %>
      Array: <%= [1, 2, 3].map { |n| n * 2 }.join(', ') %>
    TEXT
    File.write(File.join(@prompts_dir, "erb_prompt.txt"), erb_content)
    
    # Create a file to be included
    include_content = "This is included content"
    File.write(File.join(@prompts_dir, "include_file.txt"), include_content)
    
    # Create a prompt with include directive
    include_prompt_content = <<~TEXT
      //include #{File.join(@prompts_dir, "include_file.txt")}
      After include
    TEXT
    File.write(File.join(@prompts_dir, "include_prompt.txt"), include_prompt_content)
    
    # Create a prompt with ruby directive
    ruby_prompt_content = <<~TEXT
      //ruby [1, 2, 3].map { |n| n * 2 }.join(', ')
      After ruby
    TEXT
    File.write(File.join(@prompts_dir, "ruby_prompt.txt"), ruby_prompt_content)
    
    @config = OpenStruct.new(
      prompts_dir: @prompts_dir,
      roles_dir: @roles_dir,
      shell: false,
      erb: false,
      terse: false
    )
    
    # Configure PromptManager
    PromptManager.config do |c|
      c.prompts_dir = @prompts_dir
    end
  end
  
  def teardown
    # Clean up temporary directories
    FileUtils.remove_entry @prompts_dir
    FileUtils.remove_entry @roles_dir
  end
  
  def test_get_prompt_with_real_prompt_manager
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("test_prompt")
    
    assert_equal "This is a test prompt", result
  end
  
  def test_get_prompt_with_role_with_real_prompt_manager
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("test_prompt", "expert")
    
    assert_equal "You are an expert\nThis is a test prompt", result
  end
  
  def test_process_directives_with_real_prompt_manager
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("directives_prompt")
    
    assert_equal "openai/gpt-4", @config.model
    assert_equal "next_prompt", @config.next
    assert_equal ["prompt1", "prompt2"], @config.pipeline
    assert_includes result, "Normal text"
  end
  
  def test_process_prompt_with_shell_enabled
    @config.shell = true
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("shell_prompt")
    
    assert_includes result, "Echo: hello"
    assert_match(/Date: \d{4}/, result)
  end
  
  def test_process_prompt_with_erb_enabled
    @config.erb = true
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("erb_prompt")
    
    assert_includes result, "Sum: 3"
    assert_includes result, "Array: 2, 4, 6"
  end
  
  def test_process_prompt_with_include_directive
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("include_prompt")
    
    assert_includes result, "This is included content"
    assert_includes result, "After include"
  end
  
  def test_process_prompt_with_ruby_directive
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("ruby_prompt")
    
    assert_includes result, "2, 4, 6"
    assert_includes result, "After ruby"
  end
  
  def test_process_prompt_with_terse_enabled
    @config.terse = true
    handler = AIA::PromptHandler.new(@config)
    result = handler.get_prompt("test_prompt")
    
    assert_includes result, "This is a test prompt"
    assert_includes result, "Please be terse in your response."
  end
end
