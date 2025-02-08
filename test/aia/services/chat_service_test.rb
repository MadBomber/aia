require 'test_helper'

class ChatServiceTest < Minitest::Test
  def setup
    AIA::Cli.new("test") # Initialize config
    @client = mock('client')
    @directives_processor = mock('directives_processor')
    @logger = mock('logger')
    @service = AIA::Services::ChatService.new(
      client: @client,
      directives_processor: @directives_processor,
      logger: @logger
    )
  end

  def test_process_chat_with_regular_prompt
    prompt = "test prompt"
    result = "test result"
    
    @client.expects(:chat).with(prompt).returns(result)
    @logger.expects(:info).with("Follow Up:\n#{prompt}")
    @logger.expects(:info).with("Response:\n#{result}")
    
    assert_equal result, @service.process_chat(prompt)
  end

  def test_process_chat_with_directives
    prompt = "//directive test"
    directive_output = "directive result"
    result = "processed result"
    
    @directives_processor.expects(:execute_my_directives).returns(directive_output)
    @client.expects(:chat).with(directive_output).returns(result)
    @logger.expects(:info).with("Follow Up:\n#{directive_output}")
    @logger.expects(:info).with("Response:\n#{result}")
    
    assert_equal result, @service.process_chat(prompt)
  end

  def test_process_chat_with_erb_enabled
    AIA.config.erb = true
    prompt = "<%= 2 + 2 %>"
    result = "test result"
    
    # Set up expectations in the correct order
    @client.expects(:chat).with("4").returns(result)
    @logger.expects(:info).with("Follow Up:\n4")
    @logger.expects(:info).with("Response:\n#{result}")
    
    begin
      assert_equal result, @service.process_chat(prompt)
    ensure
      AIA.config.erb = false
    end
  end

  def test_process_chat_with_shell_enabled
    AIA.config.shell = true
    prompt = "$USER"
    result = "test result"
    
    # Set the environment variable
    original_user = ENV['USER']
    ENV['USER'] = 'testuser'
    
    # Set up expectations in the correct order
    @client.expects(:chat).with("testuser").returns(result)
    @logger.expects(:info).with("Follow Up:\ntestuser")
    @logger.expects(:info).with("Response:\n#{result}")
    
    begin
      assert_equal result, @service.process_chat(prompt)
    ensure
      ENV['USER'] = original_user
      AIA.config.shell = false
    end
  end
end
