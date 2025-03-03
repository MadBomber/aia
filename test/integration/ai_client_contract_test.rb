# frozen_string_literal: true

require "test_helper"
require "ai_client"

class AiClientContractTest < Minitest::Test
  def setup
    # Skip all tests if credentials aren't available
    skip "No OpenAI credentials available for integration test" unless ENV["OPENAI_API_KEY"]
    
    @test_prompt = "Say hello world in one sentence."
  end
  
  def test_client_initialization
    # Test that we can initialize an AiClient
    client = AiClient.new(provider: "openai")
    assert_instance_of AiClient, client
  end
  
  def test_chat_interface
    # Get an AiClient
    client = AiClient.new(provider: "openai")
    
    # Verify it has a chat method
    assert_respond_to client, :chat
  end
  
  def test_text_to_speech_interface
    # Get an AiClient
    client = AiClient.new(provider: "openai")
    
    # Verify it has a text_to_speech method
    assert_respond_to client, :text_to_speech
  end
  
  # For now, skip actual API calls in the contract tests
  # We'll test those in the adapter integration tests
end
