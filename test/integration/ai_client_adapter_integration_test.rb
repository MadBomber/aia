# frozen_string_literal: true

require "test_helper"
require "tempfile"

class AIA::AIClientAdapterIntegrationTest < Minitest::Test
  def setup
    # Skip all tests if credentials aren't available
    skip "No OpenAI credentials available for integration test" unless ENV["OPENAI_API_KEY"]
    
    @config = OpenStruct.new(
      model: "openai/gpt-3.5-turbo",
      temperature: 0.7,
      max_tokens: 50,
      image_size: "1024x1024",
      image_quality: "standard",
      speech_model: "tts-1",
      voice: "alloy"
    )
    
    @adapter = AIA::AIClientAdapter.new(@config)
  end
  
  def test_initialization_with_different_models
    # Test with different model formats
    models = [
      "openai/gpt-3.5-turbo",
      "openai/gpt-4",
      "gpt-3.5-turbo" # No provider prefix
    ]
    
    models.each do |model|
      config = OpenStruct.new(model: model)
      adapter = AIA::AIClientAdapter.new(config)
      
      # Just verify that initialization doesn't raise errors
      assert_instance_of AIA::AIClientAdapter, adapter
    end
  end
end
