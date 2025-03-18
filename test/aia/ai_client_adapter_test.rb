require_relative '../test_helper'

class AIClientAdapterTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      model: 'openai/gpt-4o-mini',
      transcription_model: 'whisper',
      speech_model: 'tts',
      voice: 'default',
      speak_command: 'say',
      image_size: '512x512',
      image_quality: 'high',
      image_style: 'realistic'
    )
    @adapter = AIA::AIClientAdapter.new(@config)
  end

  def test_initialization
    assert_equal 'openai', @adapter.instance_variable_get(:@provider)
    assert_equal 'gpt-4o-mini', @adapter.instance_variable_get(:@model)
  end

  def test_chat_text_to_text
    response = @adapter.chat('Hello, AI!')
    assert_instance_of String, response
  end

  def test_transcribe
    # Assuming transcribe method returns a string
    response = @adapter.transcribe('path/to/audio/file.mp3')
    assert_instance_of String, response
  end

  def test_speak
    # This test will not check the actual audio output, just that the method runs
    assert_nil @adapter.speak('Hello, AI!')
  end
end
