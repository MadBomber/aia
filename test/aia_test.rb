# frozen_string_literal: true

require "test_helper"

class AIATest < Minitest::Test
  def test_run_method
    args = ["test_prompt"]
    
    # Mock the components
    config = mock
    prompt_handler = mock
    client = mock
    session = mock
    
    # Expect component initialization
    AIA::Config.expects(:parse).with(args).returns(config)
    AIA::PromptHandler.expects(:new).with(config).returns(prompt_handler)
    AIA::AIClientAdapter.expects(:new).with(config).returns(client)
    AIA::Session.expects(:new).with(config, prompt_handler, client).returns(session)
    
    # Expect session to start
    session.expects(:start)
    
    # Run the method
    AIA.run(args)
  end
end
