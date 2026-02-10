# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'
require 'fileutils'

class ModalityHandlersTest < Minitest::Test
  def setup
    @adapter = AIA::RubyLLMAdapter.allocate
    @adapter.instance_variable_set(:@chats, {})
    @adapter.instance_variable_set(:@models, ['test-model'])
    @adapter.instance_variable_set(:@contexts, {})
    @adapter.instance_variable_set(:@tools, [])
    @adapter.instance_variable_set(:@model_specs, [
      { model: 'test-model', instance: 1, role: nil, internal_id: 'test-model' }
    ])
  end

  def teardown
    super
  end

  # --- extract_text_prompt ---

  def test_extract_text_prompt_from_string
    result = @adapter.send(:extract_text_prompt, 'hello world')
    assert_equal 'hello world', result
  end

  def test_extract_text_prompt_from_hash_with_text_key
    result = @adapter.send(:extract_text_prompt, { text: 'from text' })
    assert_equal 'from text', result
  end

  def test_extract_text_prompt_from_hash_with_content_key
    result = @adapter.send(:extract_text_prompt, { content: 'from content' })
    assert_equal 'from content', result
  end

  def test_extract_text_prompt_from_other_types
    result = @adapter.send(:extract_text_prompt, 42)
    assert_equal '42', result
  end

  def test_extract_text_prompt_prefers_text_over_content
    result = @adapter.send(:extract_text_prompt, { text: 'preferred', content: 'fallback' })
    assert_equal 'preferred', result
  end

  # --- extract_image_path ---

  def test_extract_image_path_from_string_with_jpg
    result = @adapter.send(:extract_image_path, 'look at image.jpg please')
    assert_equal 'image.jpg', result
  end

  def test_extract_image_path_from_string_with_png
    result = @adapter.send(:extract_image_path, 'check path/to/photo.png')
    assert_equal 'path/to/photo.png', result
  end

  def test_extract_image_path_from_string_with_webp
    result = @adapter.send(:extract_image_path, 'analyze image.webp')
    assert_equal 'image.webp', result
  end

  def test_extract_image_path_from_string_without_image
    result = @adapter.send(:extract_image_path, 'no image here')
    assert_nil result
  end

  def test_extract_image_path_from_hash_with_image_key
    result = @adapter.send(:extract_image_path, { image: '/path/to/img.png' })
    assert_equal '/path/to/img.png', result
  end

  def test_extract_image_path_from_hash_with_image_path_key
    result = @adapter.send(:extract_image_path, { image_path: '/img/test.jpg' })
    assert_equal '/img/test.jpg', result
  end

  # --- audio_file? ---

  def test_audio_file_detects_mp3
    assert @adapter.send(:audio_file?, 'recording.mp3')
  end

  def test_audio_file_detects_wav
    assert @adapter.send(:audio_file?, 'recording.wav')
  end

  def test_audio_file_detects_m4a
    assert @adapter.send(:audio_file?, 'recording.m4a')
  end

  def test_audio_file_detects_flac
    assert @adapter.send(:audio_file?, 'recording.flac')
  end

  def test_audio_file_rejects_non_audio
    refute @adapter.send(:audio_file?, 'document.txt')
  end

  def test_audio_file_case_insensitive
    assert @adapter.send(:audio_file?, 'recording.MP3')
  end

  def test_audio_file_handles_nil
    refute @adapter.send(:audio_file?, nil)
  end

  # --- text_to_text_single ---

  def test_text_to_text_single_asks_chat_instance
    mock_response = mock('response')
    mock_response.stubs(:content).returns('test response')

    mock_chat = mock('chat')
    mock_chat.expects(:ask).with('hello').returns(mock_response)

    @adapter.instance_variable_set(:@chats, { 'test-model' => mock_chat })

    AIA.stubs(:config).returns(OpenStruct.new(context_files: []))

    result = @adapter.send(:text_to_text_single, 'hello', 'test-model')
    assert_equal mock_response, result
  end

  def test_text_to_text_single_with_context_files
    mock_response = mock('response')

    mock_chat = mock('chat')
    mock_chat.expects(:ask).with('hello', with: ['/path/to/file.txt']).returns(mock_response)

    @adapter.instance_variable_set(:@chats, { 'test-model' => mock_chat })

    AIA.stubs(:config).returns(OpenStruct.new(context_files: ['/path/to/file.txt']))

    result = @adapter.send(:text_to_text_single, 'hello', 'test-model')
    assert_equal mock_response, result
  end

  def test_text_to_text_single_handles_exception
    mock_chat = mock('chat')
    mock_chat.stubs(:ask).raises(StandardError, 'API error')
    mock_chat.stubs(:respond_to?).with(:messages).returns(false)

    @adapter.instance_variable_set(:@chats, { 'test-model' => mock_chat })

    AIA.stubs(:config).returns(OpenStruct.new(context_files: []))

    result = @adapter.send(:text_to_text_single, 'hello', 'test-model')
    assert_includes result, 'Tool error'
    assert_includes result, 'API error'
  end

  # --- text_to_image_single ---

  def test_text_to_image_single_returns_url
    mock_image = mock('image')
    mock_image.stubs(:url).returns('https://example.com/image.png')

    RubyLLM.expects(:paint).returns(mock_image)

    AIA.stubs(:config).returns(OpenStruct.new(
      image: OpenStruct.new(size: '1024x1024')
    ))

    result = @adapter.send(:text_to_image_single, 'a cat', 'test-model')
    assert_includes result, 'https://example.com/image.png'
  end

  def test_text_to_image_single_saves_to_file
    mock_image = mock('image')
    mock_image.expects(:save).with('cat.png').returns('/tmp/cat.png')

    RubyLLM.expects(:paint).returns(mock_image)

    AIA.stubs(:config).returns(OpenStruct.new(
      image: OpenStruct.new(size: '1024x1024')
    ))

    result = @adapter.send(:text_to_image_single, 'generate cat.png', 'test-model')
    assert_includes result, 'saved to'
  end

  def test_text_to_image_single_handles_error
    RubyLLM.stubs(:paint).raises(StandardError, 'generation failed')

    AIA.stubs(:config).returns(OpenStruct.new(
      image: OpenStruct.new(size: '1024x1024')
    ))

    result = @adapter.send(:text_to_image_single, 'a cat', 'test-model')
    assert_includes result, 'Error generating image'
  end

  # --- image_to_text_single ---

  def test_image_to_text_single_with_valid_image
    Dir.mktmpdir do |tmpdir|
      # Use a relative-style path that the regex can match (no leading /)
      image_file = File.join(tmpdir, 'test.jpg')
      File.write(image_file, 'fake image data')

      mock_response = mock('response')
      mock_response.stubs(:content).returns('description of image')

      mock_chat = mock('chat')

      # Use hash input to supply the image path directly (bypasses regex extraction)
      prompt = { text: 'describe this image', image: image_file }
      mock_chat.expects(:ask).with('describe this image', with: image_file).returns(mock_response)

      @adapter.instance_variable_set(:@chats, { 'test-model' => mock_chat })

      result = @adapter.send(:image_to_text_single, prompt, 'test-model')
      assert_equal 'description of image', result
    end
  end

  def test_image_to_text_single_falls_back_to_text_when_no_image
    mock_response = mock('response')
    mock_response.stubs(:content).returns('text response')

    mock_chat = mock('chat')
    mock_chat.stubs(:ask).returns(mock_response)

    @adapter.instance_variable_set(:@chats, { 'test-model' => mock_chat })

    AIA.stubs(:config).returns(OpenStruct.new(context_files: []))

    result = @adapter.send(:image_to_text_single, 'just text, no image', 'test-model')
    assert_equal mock_response, result
  end

  # --- single_model_chat modality routing ---

  def test_single_model_chat_routes_to_text_to_text
    mock_modalities = OpenStruct.new(
      text_to_text?: true, image_to_text?: false, text_to_image?: false,
      text_to_audio?: false, audio_to_text?: false
    )

    mock_model = mock('model')
    mock_model.stubs(:modalities).returns(mock_modalities)

    mock_response = mock('response')

    mock_chat = mock('chat')
    mock_chat.stubs(:model).returns(mock_model)
    mock_chat.stubs(:ask).returns(mock_response)

    @adapter.instance_variable_set(:@chats, { 'test-model' => mock_chat })

    AIA.stubs(:config).returns(OpenStruct.new(context_files: []))

    result = @adapter.single_model_chat('hello', 'test-model')
    assert_equal mock_response, result
  end

  def test_single_model_chat_returns_error_for_unknown_modality
    mock_modalities = OpenStruct.new(
      text_to_text?: false, image_to_text?: false, text_to_image?: false,
      text_to_audio?: false, audio_to_text?: false
    )

    mock_model = mock('model')
    mock_model.stubs(:modalities).returns(mock_modalities)

    mock_chat = mock('chat')
    mock_chat.stubs(:model).returns(mock_model)

    @adapter.instance_variable_set(:@chats, { 'test-model' => mock_chat })

    result = @adapter.single_model_chat('hello', 'test-model')
    assert_includes result, 'Error: No matching modality'
  end
end
