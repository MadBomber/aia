# frozen_string_literal: true

require "test_helper"
require "prompt_manager"
require "fileutils"

class PromptManagerContractTest < Minitest::Test
  def setup
    # Set up a temporary directory for prompts
    @temp_dir = Dir.mktmpdir
    @prompt_content = "Test prompt content"
    
    # Create a test prompt file
    File.write(File.join(@temp_dir, "test_prompt.txt"), @prompt_content)
    
    # Configure PromptManager to use the temp directory
    PromptManager.config do |c|
      c.prompts_dir = @temp_dir
    end
  end
  
  def teardown
    # Clean up the temporary directory
    FileUtils.remove_entry @temp_dir
  end
  
  def test_prompt_get_returns_prompt_with_text_method
    # This test verifies that PromptManager::Prompt.get returns an object
    # with a text method that returns the content of the prompt file
    prompt = PromptManager::Prompt.get(id: "test_prompt")
    assert_respond_to prompt, :text
    assert_equal @prompt_content, prompt.text
  end
  
  def test_prompt_text_can_be_modified
    # This test verifies that we can modify the text of a prompt
    prompt = PromptManager::Prompt.get(id: "test_prompt")
    new_text = "Modified text"
    prompt.text = new_text
    assert_equal new_text, prompt.text
  end
  
  def test_storage_adapter_initialization
    # This test verifies that we can initialize a storage adapter with a directory
    adapter = PromptManager::Storage.new(dir: @temp_dir)
    prompt = PromptManager::Prompt.get(id: "test_prompt", storage: adapter)
    assert_equal @prompt_content, prompt.text
  end
end
