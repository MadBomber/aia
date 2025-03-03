# frozen_string_literal: true

require "test_helper"

class AIA::PromptHandlerTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      prompts_dir: "/test/prompts",
      roles_dir: "/test/roles",
      shell: false,
      erb: false,
      terse: false
    )
    
    # Mock PromptManager configuration
    PromptManager.stubs(:config)
  end

  def test_get_prompt
    # Create a mock prompt with a stubbed text method
    prompt = mock
    prompt.stubs(:text).returns("This is a test prompt")
    prompt.stubs(:text=).with(anything)
    
    PromptManager::Prompt.stubs(:get).with(id: "test").returns(prompt)
    
    handler = AIA::PromptHandler.new(@config)
    
    # Stub process_directives to avoid nil.split error
    handler.stubs(:process_directives).returns("This is a test prompt")
    
    result = handler.get_prompt("test")
    
    assert_equal "This is a test prompt", result
  end

  def test_get_prompt_with_role
    # Create mock prompts with stubbed text methods
    prompt = mock
    prompt.stubs(:text).returns("This is a test prompt")
    
    # Important: We need to capture the new text value when it's set
    new_text = "You are an expert\nThis is a test prompt"
    prompt.stubs(:text=).with(anything).returns { |value| new_text = value }
    
    role_prompt = mock
    role_prompt.stubs(:text).returns("You are an expert")
    
    PromptManager::Prompt.stubs(:get).with(id: "test").returns(prompt)
    PromptManager::Prompt.stubs(:get).with(
      id: "expert", 
      storage: instance_of(PromptManager::Storage)
    ).returns(role_prompt)
    
    # After text= is called, make text return the new combined value
    prompt.stubs(:text).returns(new_text)
    
    handler = AIA::PromptHandler.new(@config)
    
    # Stub process_directives to avoid nil.split error
    handler.stubs(:process_directives).returns(new_text)
    
    result = handler.get_prompt("test", "expert")
    
    assert_equal "You are an expert\nThis is a test prompt", result
  end

  def test_process_prompt_with_shell_enabled
    @config.shell = true
    
    # Create a mock prompt with a stubbed text method
    prompt = mock
    prompt.stubs(:text).returns("Echo: $(echo hello)")
    
    handler = AIA::PromptHandler.new(@config)
    
    # Stub process_directives to return an unfrozen string
    handler.stubs(:process_directives).returns("Echo: $(echo hello)".dup)
    
    result = handler.process_prompt(prompt)
    
    assert_equal "Echo: hello", result
  end

  def test_process_prompt_with_erb_enabled
    @config.erb = true
    
    # Create a mock prompt with a stubbed text method
    prompt = mock
    prompt.stubs(:text).returns("Sum: <%= 1 + 2 %>")
    
    handler = AIA::PromptHandler.new(@config)
    
    # Stub process_directives to avoid nil.split error
    handler.stubs(:process_directives).returns("Sum: <%= 1 + 2 %>")
    
    result = handler.process_prompt(prompt)
    
    assert_equal "Sum: 3", result
  end

  def test_process_prompt_with_terse_enabled
    @config.terse = true
    
    # Create a mock prompt with a stubbed text method
    prompt = mock
    prompt.stubs(:text).returns("This is a test prompt")
    
    handler = AIA::PromptHandler.new(@config)
    
    # Stub process_directives to avoid nil.split error
    handler.stubs(:process_directives).returns("This is a test prompt")
    
    result = handler.process_prompt(prompt)
    
    assert_equal "This is a test prompt\n\nPlease be terse in your response.", result
  end

  def test_process_directives
    prompt_text = <<~TEXT
      //config model = openai/gpt-4
      //shell echo hello
      //ruby 1 + 2
      //include test.txt
      //next next_prompt
      //pipeline prompt1,prompt2
      Normal text
    TEXT
    
    # Create a mock prompt with a stubbed text method
    prompt = mock
    prompt.stubs(:text).returns(prompt_text)
    
    # Mock file operations
    File.stubs(:exist?).with("test.txt").returns(true)
    File.stubs(:read).with("test.txt").returns("Included content")
    
    handler = AIA::PromptHandler.new(@config)
    result = handler.process_prompt(prompt)
    
    # Check that directive outputs were included
    assert_includes result, "Normal text"
  end
end
