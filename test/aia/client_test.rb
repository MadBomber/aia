# test/aia/client_test.rb

require 'test_helper'

class ClientTest < Minitest::Test
  def setup
    # Ensure we have a valid prompt ID for all tests
    @original_args = AIA.config&.arguments
    @test_prompts_dir = File.expand_path('../prompts_dir', __FILE__)
    
    # Create test prompt file if it doesn't exist
    @test_prompt_file = File.join(@test_prompts_dir, 'test.txt')
    unless File.exist?(@test_prompt_file)
      FileUtils.mkdir_p(@test_prompts_dir)
      FileUtils.mkdir_p(@test_prompts_dir)
      File.write(@test_prompt_file, "Test prompt content") unless File.exist?(@test_prompt_file)
    end
    
    # Set up environment for tests
    ENV['AIA_PROMPTS_DIR'] = @test_prompts_dir
    ENV['AIA_LOG_FILE'] = File.expand_path('../../tmp/test.log', __FILE__)
    FileUtils.mkdir_p(File.dirname(ENV['AIA_LOG_FILE']))
    
    AIA::Cli.new(["test"]) 
  end

  def teardown
    # Restore original arguments
    AIA.config.arguments = @original_args if @original_args
    File.delete(ENV['AIA_LOG_FILE']) if File.exist?(ENV['AIA_LOG_FILE'])
  end

  def test_chat_returns_ai_client
    client = AIA::Client.chat
    assert_instance_of AiClient, client
    assert_equal AIA.config.model, client.model
  end

  def test_tts_returns_ai_client
    client = AIA::Client.tts
    assert_instance_of AiClient, client
    assert_equal AIA.config.speech_model, client.model
  end

  def test_image_returns_ai_client
    client = AIA::Client.image
    assert_instance_of AiClient, client
    assert_equal AIA.config.image_model, client.model
  end

  def test_audio_returns_ai_client
    client = AIA::Client.audio
    assert_instance_of AiClient, client
    assert_equal AIA.config.audio_model, client.model
  end

  def test_handles_piped_input
    original_stdin = $stdin
    input = StringIO.new("piped content")
    $stdin = input

    begin
      assert_equal "piped content", $stdin.read
    ensure
      $stdin = original_stdin
    end
  end
end

require 'test_helper'

class AIA::ClientTest < Minitest::Test
  def setup
    @client = AIA::Client
  end

  def test_has_tts_client
    assert_respond_to @client, :tts
    assert_instance_of AiClient, @client.tts
  end

  def test_has_chat_client
    assert_respond_to @client, :chat
    assert_instance_of AiClient, @client.chat
  end

  def test_has_image_client
    assert_respond_to @client, :image
    assert_instance_of AiClient, @client.image
  end

  def test_has_audio_client
    assert_respond_to @client, :audio
    assert_instance_of AiClient, @client.audio
  end
end
