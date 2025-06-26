require_relative 'test_helper'

## Define the base module to allow the extension to load without the real gem
module RubyLLM
  module Model; end
end
require 'extensions/ruby_llm/modalities'

class RubyLLMModalitiesTest < Minitest::Test
  INPUT_TYPES = %w[text image pdf audio file]
  OUTPUT_TYPES = %w[text embeddings audio image moderation]

  def setup
    @mod = RubyLLM::Model::Modalities.new
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
end