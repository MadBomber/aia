# frozen_string_literal: true

# test/aia/config/cli_parser_model_query_test.rb
#
# Isolation tests for the query-parsing and matching helpers extracted
# from CLIParser::list_available_models.

require_relative '../../test_helper'
require 'ostruct'

class CLIParserModelQueryTest < Minitest::Test
  # =========================================================================
  # parse_model_query
  # =========================================================================

  def test_parse_model_query_splits_modality_and_substring_terms
    modality, substrings = AIA::CLIParser.send(:parse_model_query,
                                               ['text_to_text', 'gpt', ':image_to_text'])
    assert_equal %w[text_to_text image_to_text], modality
    assert_equal ['gpt'], substrings
  end

  def test_parse_model_query_empty
    assert_equal [[], []], AIA::CLIParser.send(:parse_model_query, [])
  end

  # =========================================================================
  # format_model_entry / model_entry_visible?
  # =========================================================================

  def stub_llm
    modalities = OpenStruct.new(input: %w[text image], output: ['text'])
    def modalities.text_to_text? = true
    def modalities.image_to_image? = false
    OpenStruct.new(id: 'gpt-x', provider: 'openai', modalities: modalities)
  end

  def test_format_model_entry
    assert_equal '- gpt-x (openai) text,image to text',
                 AIA::CLIParser.send(:format_model_entry, stub_llm)
  end

  def test_model_entry_visible_with_no_terms
    llm = stub_llm
    entry = AIA::CLIParser.send(:format_model_entry, llm)
    assert AIA::CLIParser.send(:model_entry_visible?, llm, entry, [], [])
  end

  def test_model_entry_visible_checks_modalities_and_substrings
    llm = stub_llm
    entry = AIA::CLIParser.send(:format_model_entry, llm)

    assert AIA::CLIParser.send(:model_entry_visible?, llm, entry, ['text_to_text'], ['openai'])
    refute AIA::CLIParser.send(:model_entry_visible?, llm, entry, ['image_to_image'], [])
    refute AIA::CLIParser.send(:model_entry_visible?, llm, entry, [], ['anthropic'])
  end
end
