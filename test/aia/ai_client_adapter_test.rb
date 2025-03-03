# frozen_string_literal: true

require "test_helper"
require 'tempfile'

class AIA::AIClientAdapterTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      model: "openai/gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      image_size: "1024x1024",
      image_quality: "standard",
      speech_model: "tts-1",
      voice: "alloy"
    )
    
    # Define constants if they don't exist
    unless defined?(::AiClient)
      Object.const_set(:AiClient, Module.new)
    end
  end

  def test_initialization_with_provider_and_model
    adapter = AIA::AIClientAdapter.new(@config)
    assert_equal "openai", adapter.instance_variable_get(:@provider)
    assert_equal "gpt-4", adapter.instance_variable_get(:@model)
  end

  def test_initialization_with_model_only
    @config.model = "gpt-4"
    
    adapter = AIA::AIClientAdapter.new(@config)
    assert_equal "gpt-4", adapter.instance_variable_get(:@provider)
    assert_equal "gpt-4", adapter.instance_variable_get(:@model)
  end

  def test_chat
    # Stub AiClient.chat
    if defined?(::AiClient)
      AiClient.stubs(:chat).returns("Hello, human")
    end
    
    adapter = AIA::AIClientAdapter.new(@config)
    adapter.instance_variable_set(:@provider, "openai")
    adapter.instance_variable_set(:@model, "gpt-4")
    
    # Skip test if AiClient.chat isn't defined
    if defined?(::AiClient) && AiClient.respond_to?(:chat)
      response = adapter.chat("Hello, AI")
      assert_equal "Hello, human", response
    else
      skip "AiClient.chat not available"
    end
  end

  def test_speak_with_siri_on_mac
    @config.voice = "siri"
    
    # Mock platform check
    Object.stubs(:const_get).with(:RUBY_PLATFORM).returns("darwin")
    
    # Expect system call to say command
    adapter = AIA::AIClientAdapter.new(@config)
    adapter.expects(:system).with("say", "Hello").returns(true)
    
    result = adapter.speak("Hello")
    assert result
  end

  def test_speak_with_openai_voice
    skip "Skipping text_to_speech test"
  end
end
