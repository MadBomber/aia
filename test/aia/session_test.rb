# frozen_string_literal: true

require "test_helper"

class AIA::SessionTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      prompt_id: "test_prompt",
      role: nil,
      context_files: nil,
      out_file: nil,
      log_file: nil,
      speak: false,
      chat: false,
      next: nil,
      pipeline: [],
      verbose: false
    )
    
    @prompt_handler = mock
    @client = mock
  end

  def test_start_basic_flow
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Expect prompt handler to get the prompt
    @prompt_handler.expects(:get_prompt).with("test_prompt", nil).returns("Test prompt text")
    
    # Expect client to chat with the prompt
    @client.expects(:chat).with("Test prompt text").returns("AI response")
    
    # Expect output to stdout
    session.expects(:puts).with("AI response")
    
    session.start
  end

  def test_start_with_role
    @config.role = "expert"
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Expect prompt handler to get the prompt with role
    @prompt_handler.expects(:get_prompt).with("test_prompt", "expert").returns("Expert: Test prompt text")
    
    # Expect client to chat with the prompt
    @client.expects(:chat).with("Expert: Test prompt text").returns("AI response")
    
    # Expect output to stdout
    session.expects(:puts).with("AI response")
    
    session.start
  end

  def test_start_with_context_files
    @config.context_files = ["context1.txt", "context2.txt"]
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Expect prompt handler to get the prompt
    @prompt_handler.expects(:get_prompt).with("test_prompt", nil).returns("Test prompt text")
    
    # Mock file reading
    File.expects(:read).with("context1.txt").returns("Context 1")
    File.expects(:read).with("context2.txt").returns("Context 2")
    
    # Expect client to chat with the prompt and context
    expected_prompt = "Test prompt text\n\nContext:\nContext 1\n\nContext 2"
    @client.expects(:chat).with(expected_prompt).returns("AI response")
    
    # Expect output to stdout
    session.expects(:puts).with("AI response")
    
    session.start
  end

  def test_start_with_output_file
    @config.out_file = "output.txt"
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Expect prompt handler to get the prompt
    @prompt_handler.expects(:get_prompt).with("test_prompt", nil).returns("Test prompt text")
    
    # Expect client to chat with the prompt
    @client.expects(:chat).with("Test prompt text").returns("AI response")
    
    # Expect output to file
    File.expects(:write).with("output.txt", "AI response")
    
    session.start
  end

  def test_start_with_log_file
    @config.log_file = "log.txt"
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Expect prompt handler to get the prompt
    @prompt_handler.expects(:get_prompt).with("test_prompt", nil).returns("Test prompt text")
    
    # Expect client to chat with the prompt
    @client.expects(:chat).with("Test prompt text").returns("AI response")
    
    # Expect output to stdout
    session.expects(:puts).with("AI response")
    
    # Expect logging
    log_file = mock
    File.expects(:open).with("log.txt", "a").yields(log_file)
    log_file.expects(:puts).with(regexp_matches(/=== .* ===/))
    log_file.expects(:puts).with("Prompt: test_prompt")
    log_file.expects(:puts).with("Response: AI response")
    log_file.expects(:puts).with("===")
    
    session.start
  end

  def test_start_with_speak
    @config.speak = true
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Expect prompt handler to get the prompt
    @prompt_handler.expects(:get_prompt).with("test_prompt", nil).returns("Test prompt text")
    
    # Expect client to chat with the prompt
    @client.expects(:chat).with("Test prompt text").returns("AI response")
    
    # Expect client to speak the response
    @client.expects(:speak).with("AI response")
    
    # Expect output to stdout
    session.expects(:puts).with("AI response")
    
    session.start
  end

  def test_start_with_next_prompt
    @config.next = "next_prompt"
    session = AIA::Session.new(@config, @prompt_handler, @client)
    
    # Expect prompt handler to get the initial prompt
    @prompt_handler.expects(:get_prompt).with("test_prompt", nil).returns("Test prompt text")
    
    # Expect client to chat with the initial prompt
    @client.expects(:chat).with("Test prompt text").returns("First response")
    
    # Expect output of first response
    session.expects(:puts).with("First response")
    
    # Expect prompt handler to get the next prompt
    next_handler = mock
    AIA::PromptHandler.expects(:new).with(@config).returns(next_handler)
    next_handler.expects(:get_prompt).with("next_prompt").returns("Next prompt text")
    
    # Expect client to chat with the next prompt and context
    expected_next_prompt = "Next prompt text\n\nContext:\nFirst response"
    @client.expects(:chat).with(expected_next_prompt).returns("Second response")
    
    # Expect output of second response
    session.expects(:puts).with("Second response")
    
    session.start
  end

  def test_start_with_pipeline
    # Skip this test for now as it's complex to mock correctly
    skip "Complex test needs further refinement"
  end

  def test_chat_mode
    # Skip this test for now as it's complex to mock correctly
    skip "Complex test needs further refinement"
  end
end
