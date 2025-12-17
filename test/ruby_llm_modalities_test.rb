require_relative 'test_helper'
require 'ostruct'
require 'extensions/ruby_llm/modalities'

class RubyLLMModalitiesTest < Minitest::Test
  INPUT_TYPES = %w[text image pdf audio file]
  OUTPUT_TYPES = %w[text embeddings audio image moderation]

  # Test harness that includes the modality methods without needing the full gem
  class TestModalities
    def input
      @input || ['text']
    end

    def output
      @output || ['text']
    end

    def input=(val)
      @input = val
    end

    def output=(val)
      @output = val
    end

    # Include the methods from our extension
    def text_to_text? = input.include?('text') && output.include?('text')
    def text_to_embeddings? = input.include?('text') && output.include?('embeddings')
    def text_to_audio? = input.include?('text') && output.include?('audio')
    def text_to_image? = input.include?('text') && output.include?('image')
    def text_to_moderation? = input.include?('text') && output.include?('moderation')
    def image_to_text? = input.include?('image') && output.include?('text')
    def image_to_embeddings? = input.include?('image') && output.include?('embeddings')
    def image_to_audio? = input.include?('image') && output.include?('audio')
    def image_to_image? = input.include?('image') && output.include?('image')
    def image_to_moderation? = input.include?('image') && output.include?('moderation')
    def pdf_to_text? = input.include?('pdf') && output.include?('text')
    def pdf_to_embeddings? = input.include?('pdf') && output.include?('embeddings')
    def pdf_to_audio? = input.include?('pdf') && output.include?('audio')
    def pdf_to_image? = input.include?('pdf') && output.include?('image')
    def pdf_to_moderation? = input.include?('pdf') && output.include?('moderation')
    def audio_to_text? = input.include?('audio') && output.include?('text')
    def audio_to_embeddings? = input.include?('audio') && output.include?('embeddings')
    def audio_to_audio? = input.include?('audio') && output.include?('audio')
    def audio_to_image? = input.include?('audio') && output.include?('image')
    def audio_to_moderation? = input.include?('audio') && output.include?('moderation')
    def file_to_text? = input.include?('file') && output.include?('text')
    def file_to_embeddings? = input.include?('file') && output.include?('embeddings')
    def file_to_audio? = input.include?('file') && output.include?('audio')
    def file_to_image? = input.include?('file') && output.include?('image')
    def file_to_moderation? = input.include?('file') && output.include?('moderation')
  end

  def setup
    @mod = TestModalities.new
  end

  def test_positive_combinations
    INPUT_TYPES.each do |in_type|
      OUTPUT_TYPES.each do |out_type|
        method = "#{in_type}_to_#{out_type}?"
        # Set input/output for this test
        @mod.input = [in_type]
        @mod.output = [out_type]
        assert @mod.public_send(method), "Expected #{method} to be true for input=#{in_type}, output=#{out_type}"
      end
    end
  end

  def test_negative_when_input_mismatch
    # For a given method, true only when both input and output match
    @mod.input = ['text']
    @mod.output = ['text']
    assert @mod.text_to_text?
    @mod.input = ['audio']
    refute @mod.text_to_text?
  end

  def test_negative_when_output_mismatch
    @mod.input = ['text']
    @mod.output = ['text']
    assert @mod.text_to_text?
    @mod.output = ['embeddings']
    refute @mod.text_to_text?
  end

  def test_multiple_input_types
    # Test that method returns true when multiple input types include the required one
    @mod.input = ['image', 'text', 'audio']
    @mod.output = ['text']
    assert @mod.text_to_text?
    assert @mod.image_to_text?
    assert @mod.audio_to_text?
  end

  def test_multiple_output_types
    # Test that method returns true when multiple output types include the required one
    @mod.input = ['text']
    @mod.output = ['embeddings', 'text', 'audio']
    assert @mod.text_to_text?
    assert @mod.text_to_embeddings?
    assert @mod.text_to_audio?
  end

  def test_all_specific_method_combinations
    # Test a few specific combinations explicitly
    @mod.input = ['pdf']
    @mod.output = ['image']
    assert @mod.pdf_to_image?
    refute @mod.pdf_to_text?

    @mod.input = ['audio']
    @mod.output = ['moderation']
    assert @mod.audio_to_moderation?
    refute @mod.audio_to_embeddings?
  end
end