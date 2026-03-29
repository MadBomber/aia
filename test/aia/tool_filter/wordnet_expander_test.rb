# frozen_string_literal: true
# test/aia/tool_filter/wordnet_expander_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia/tool_filter/wordnet_expander'

class WordNetExpanderTest < Minitest::Test
  def setup
    AIA::ToolFilter::WordNetExpander.reset_for_testing!
  end

  def teardown
    AIA::ToolFilter::WordNetExpander.reset_for_testing!
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

  # ------------------------------------------------------------------
  # CI-safe unit tests (stub query_wn to work without wn installed)
  # ------------------------------------------------------------------

  def test_synonyms_for_combines_noun_and_verb_results
    AIA::ToolFilter::WordNetExpander.stubs(:query_wn).with("find", 'n').returns(["search", "hunt"])
    AIA::ToolFilter::WordNetExpander.stubs(:query_wn).with("find", 'v').returns(["seek", "look"])
    result = AIA::ToolFilter::WordNetExpander.synonyms_for("find")
    assert_includes result, "search"
    assert_includes result, "seek"
    refute_includes result, "find", "should not include the queried word itself"
  ensure
    AIA::ToolFilter::WordNetExpander.unstub(:query_wn)
  end

  def test_synonyms_for_deduplicates_across_pos
    AIA::ToolFilter::WordNetExpander.stubs(:query_wn).with("find", 'n').returns(["search", "seek"])
    AIA::ToolFilter::WordNetExpander.stubs(:query_wn).with("find", 'v').returns(["seek", "hunt"])
    result = AIA::ToolFilter::WordNetExpander.synonyms_for("find")
    assert_equal result.uniq, result, "synonyms_for should not contain duplicates"
  ensure
    AIA::ToolFilter::WordNetExpander.unstub(:query_wn)
  end

  def test_expand_uses_synonyms_for_each_long_word
    AIA::ToolFilter::WordNetExpander.stubs(:available?).returns(true)
    AIA::ToolFilter::WordNetExpander.stubs(:synonyms_for).with("find").returns(["search"])
    AIA::ToolFilter::WordNetExpander.stubs(:synonyms_for).with("file").returns(["document"])
    result = AIA::ToolFilter::WordNetExpander.expand("find file")
    assert result.include?("search"), "expected 'search' in: #{result.inspect}"
    assert result.include?("document"), "expected 'document' in: #{result.inspect}"
    assert result.start_with?("find file"), "original text should be at start"
  ensure
    AIA::ToolFilter::WordNetExpander.unstub(:available?)
    AIA::ToolFilter::WordNetExpander.unstub(:synonyms_for)
  end
end
