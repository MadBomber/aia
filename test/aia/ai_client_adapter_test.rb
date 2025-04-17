require_relative '../test_helper'
require 'ostruct'

class AIClientAdapterTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      model: 'gpt-4o-mini',
      transcription_model: 'whisper',
      speech_model: 'tts',
      voice: 'default',
      speak_command: 'say',
      image_size: '512x512',
      image_quality: 'high',
      image_style: 'realistic'
    )
    @config.prompt_id = 'test_prompt_id'
    @adapter = AIA::AIClientAdapter.new(@config)
    @client_mock = Minitest::Mock.new
    @adapter.instance_variable_set(:@client, @client_mock)
  end

  def test_initialization
    assert_equal 'gpt-4o-mini', @adapter.instance_variable_get(:@model)
  end

  def test_chat_text_to_text
    @client_mock.expect(:chat, "Hello, user!", ['Hello, AI!'])
    response = @adapter.chat('Hello, AI!')
    @client_mock.verify
    assert_instance_of String, response
  end

  def test_transcribe
    @client_mock.expect(:transcribe, "Transcribed text", ['path/to/audio.mp3'])
    response = @adapter.transcribe('path/to/audio.mp3')
    @client_mock.verify
    assert_instance_of String, response
  end

  def test_speak
    # Force a specific timestamp to ensure our output file name matches
    timestamp = 123456789
    Time.stubs(:now).returns(Time.at(timestamp))
    expected_output_file = "#{timestamp}.mp3"
    # Expect the client to call speak with the exact parameters
    expected_options = {model: "tts", voice: "default"}
    @client_mock.expect(:speak, nil, ['Hello, world!', expected_output_file, expected_options])
    # Stub the system call and file existence check
    File.stubs(:exist?).with(expected_output_file).returns(true)
    @adapter.stubs(:system).with("which say > /dev/null 2>&1").returns(true)
    @adapter.stubs(:system).with("say #{expected_output_file}").returns(true)
    # Call the speak method
    @adapter.speak('Hello, world!')
    # Verify the client mock
    @client_mock.verify
  end
end
