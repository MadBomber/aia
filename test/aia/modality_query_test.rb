# frozen_string_literal: true

# test/aia/modality_query_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia/modality_query'

class ModalityQueryTest < Minitest::Test
  Modalities = Struct.new(:input, :output)

  def setup
    @image_model = Modalities.new(%w[text image], %w[image])
    @chat_model  = Modalities.new(%w[text], %w[text])
  end

  def test_modality_term_detects_input_to_output_form
    assert AIA::ModalityQuery.modality_term?('text_to_image')
    refute AIA::ModalityQuery.modality_term?('openai')
  end

  def test_matches_when_input_and_output_are_listed
    assert AIA::ModalityQuery.matches?(@image_model, 'text_to_image')
    assert AIA::ModalityQuery.matches?(@image_model, 'image_to_image')
  end

  def test_does_not_match_when_output_is_missing
    refute AIA::ModalityQuery.matches?(@chat_model, 'text_to_image')
  end

  def test_leading_colon_and_case_are_ignored
    assert AIA::ModalityQuery.matches?(@image_model, ':Text_to_Image')
  end

  def test_incomplete_term_never_matches
    refute AIA::ModalityQuery.matches?(@image_model, '_to_image')
    refute AIA::ModalityQuery.matches?(@image_model, 'text_to_')
  end

  def test_symbol_modalities_are_accepted
    model = Modalities.new(%i[text], %i[audio])
    assert AIA::ModalityQuery.matches?(model, 'text_to_audio')
  end
end
