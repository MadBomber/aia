require_relative 'test_helper'
require 'ostruct'

## Define the base module to allow the extension to load without the real gem
module RubyLLM
  module Model; end
end
require 'extensions/ruby_llm/modalities'

class RubyLLMModalitiesTest < Minitest::Test
  INPUT_TYPES = %w[text image pdf audio file]
  OUTPUT_TYPES = %w[text embeddings audio image moderation]

  def setup
    # Create a mock model object for the Modalities constructor
    mock_model = OpenStruct.new(input: ['text'], output: ['text'])
    @mod = RubyLLM::Model::Modalities.new(mock_model)
    # Define default input and output methods
    @mod.define_singleton_method(:input) { ['text'] }
    @mod.define_singleton_method(:output) { ['text'] }
  end

  def test_positive_combinations
    INPUT_TYPES.each do |in_type|
      OUTPUT_TYPES.each do |out_type|
        method = "#{in_type}_to_#{out_type}?"
        # Define input/output for this test
        @mod.define_singleton_method(:input) { [in_type] }
        @mod.define_singleton_method(:output) { [out_type] }
        assert @mod.public_send(method), "Expected #{method} to be true for input=#{in_type}, output=#{out_type}"
      end
    end
  end

  def test_negative_when_input_mismatch
    # For a given method, true only when both input and output match
    @mod.define_singleton_method(:input) { ['text'] }
    @mod.define_singleton_method(:output) { ['text'] }
    assert @mod.text_to_text?
    @mod.define_singleton_method(:input) { ['audio'] }
    refute @mod.text_to_text?
  end

  def test_negative_when_output_mismatch
    @mod.define_singleton_method(:input) { ['text'] }
    @mod.define_singleton_method(:output) { ['text'] }
    assert @mod.text_to_text?
    @mod.define_singleton_method(:output) { ['embeddings'] }
    refute @mod.text_to_text?
  end

  def test_multiple_input_types
    # Test that method returns true when multiple input types include the required one
    @mod.define_singleton_method(:input) { ['image', 'text', 'audio'] }
    @mod.define_singleton_method(:output) { ['text'] }
    assert @mod.text_to_text?
    assert @mod.image_to_text?
    assert @mod.audio_to_text?
  end

  def test_multiple_output_types
    # Test that method returns true when multiple output types include the required one
    @mod.define_singleton_method(:input) { ['text'] }
    @mod.define_singleton_method(:output) { ['embeddings', 'text', 'audio'] }
    assert @mod.text_to_text?
    assert @mod.text_to_embeddings?
    assert @mod.text_to_audio?
  end

  def test_all_specific_method_combinations
    # Test a few specific combinations explicitly
    @mod.define_singleton_method(:input) { ['pdf'] }
    @mod.define_singleton_method(:output) { ['image'] }
    assert @mod.pdf_to_image?
    refute @mod.pdf_to_text?
    
    @mod.define_singleton_method(:input) { ['audio'] }
    @mod.define_singleton_method(:output) { ['moderation'] }
    assert @mod.audio_to_moderation?
    refute @mod.audio_to_embeddings?
  end
end