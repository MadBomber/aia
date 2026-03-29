# frozen_string_literal: true
# test/aia/tool_filter/wordnet_expander_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia/tool_filter/wordnet_expander'

class WordNetExpanderTest < Minitest::Test
  def setup
    AIA::ToolFilter::WordNetExpander.clear_cache!
  end

  def test_available_returns_boolean
    result = AIA::ToolFilter::WordNetExpander.available?
    assert result == true || result == false
  end

  def test_synonyms_for_returns_array
    skip "wn not installed" unless AIA::ToolFilter::WordNetExpander.available?
    result = AIA::ToolFilter::WordNetExpander.synonyms_for("search")
    assert_instance_of Array, result
  end

  def test_synonyms_for_includes_wordnet_synonyms
    skip "wn not installed" unless AIA::ToolFilter::WordNetExpander.available?
    result = AIA::ToolFilter::WordNetExpander.synonyms_for("search")
    assert(result.any? { |w| %w[seek hunt explore].include?(w) },
           "Expected synonyms of 'search' to include seek, hunt, or explore. Got: #{result.inspect}")
  end

  def test_synonyms_for_unknown_word_returns_empty_array
    skip "wn not installed" unless AIA::ToolFilter::WordNetExpander.available?
    result = AIA::ToolFilter::WordNetExpander.synonyms_for("xyzzy99nonword")
    assert_equal [], result
  end

  def test_synonyms_for_caches_result
    skip "wn not installed" unless AIA::ToolFilter::WordNetExpander.available?
    result1 = AIA::ToolFilter::WordNetExpander.synonyms_for("search")
    result2 = AIA::ToolFilter::WordNetExpander.synonyms_for("search")
    assert_same result1, result2, "Second call should return cached object"
  end

  def test_expand_appends_synonyms_to_text
    skip "wn not installed" unless AIA::ToolFilter::WordNetExpander.available?
    result = AIA::ToolFilter::WordNetExpander.expand("search files")
    assert result.start_with?("search files"),
           "expand should preserve original text at start"
    assert result.length > "search files".length,
           "expand should add synonym terms (got: #{result.inspect})"
  end

  def test_expand_returns_text_unchanged_when_wn_unavailable
    AIA::ToolFilter::WordNetExpander.stubs(:available?).returns(false)
    result = AIA::ToolFilter::WordNetExpander.expand("search files")
    assert_equal "search files", result
  ensure
    AIA::ToolFilter::WordNetExpander.unstub(:available?)
  end
end
