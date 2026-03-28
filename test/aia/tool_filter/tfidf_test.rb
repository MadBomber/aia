# frozen_string_literal: true
# test/aia/tool_filter/tfidf_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'

class ToolFilterTFIDFTest < Minitest::Test
  # =========================================================================
  # Test helpers — mock tool objects
  # =========================================================================

  MockTool = Struct.new(:name, :description)

  def build_tools
    [
      MockTool.new("file_search", "Search for files by name or pattern in the filesystem"),
      MockTool.new("web_browser", "Browse web pages and extract content from URLs"),
      MockTool.new("code_runner", "Execute Ruby code snippets and return results"),
      MockTool.new("database_query", "Run SQL queries against PostgreSQL databases"),
      MockTool.new("email_sender", "Send emails via SMTP with attachments"),
      MockTool.new("image_gen", "Generate images from text descriptions using DALL-E"),
      MockTool.new("calculator", "Perform mathematical calculations and unit conversions"),
    ]
  end

  def build_filter(tools = build_tools, threshold: 0.05, max_tools: 30)
    fact_asserter = AIA::FactAsserter.new
    filter = AIA::ToolFilter::TFIDF.new(
      tools: tools, fact_asserter: fact_asserter,
      threshold: threshold, max_tools: max_tools
    )
    filter.prep
    filter
  end

  # =========================================================================
  # Construction & prep
  # =========================================================================

  def test_builds_index_from_tools
    filter = build_filter
    assert_equal 7, filter.tool_count
  end

  def test_empty_tools_builds_empty_index
    filter = build_filter([])
    assert_equal 0, filter.tool_count
  end

  def test_label
    filter = build_filter
    assert_equal "TF-IDF", filter.label
  end

  def test_prep_captures_timing
    filter = build_filter
    assert filter.prep_ms > 0.0
  end

  def test_available_after_prep
    filter = build_filter
    assert filter.available?
  end

  def test_not_available_with_empty_tools
    filter = build_filter([])
    refute filter.available?
  end

  # =========================================================================
  # Filtering
  # =========================================================================

  def test_relevant_tools_ranked_higher
    filter = build_filter
    results = filter.filter_with_scores("search for a file named config.yml")

    names = results.map { |r| r[:name] }
    assert_includes names, "file_search", "file_search should match a file search prompt"

    if results.size > 1
      file_entry = results.find { |r| r[:name] == "file_search" }
      assert file_entry[:score] > 0.0
    end
  end

  def test_filter_returns_tool_names
    filter = build_filter
    names = filter.filter("run a SQL query to find users")
    assert_kind_of Array, names
    names.each { |n| assert_kind_of String, n }
  end

  def test_threshold_filtering
    filter = build_filter(threshold: 0.99)
    results = filter.filter("something vaguely related")
    # With a very high threshold, few or no tools should match
    assert results.nil? || results.size <= 2,
      "Very high threshold should filter aggressively (got #{results&.size})"
  end

  def test_max_tools_cap
    filter = build_filter(threshold: 0.0, max_tools: 3)
    results = filter.filter("tools for everything")
    assert results.nil? || results.size <= 3,
      "Should cap at max_tools (got #{results&.size})"
  end

  # =========================================================================
  # Edge cases
  # =========================================================================

  def test_nil_prompt_returns_nil
    filter = build_filter
    assert_nil filter.filter(nil)
  end

  def test_empty_prompt_returns_nil
    filter = build_filter
    assert_nil filter.filter("")
    assert_nil filter.filter("   ")
  end

  def test_tools_with_missing_descriptions
    tools = [
      MockTool.new("no_desc_tool", ""),
      MockTool.new("has_desc", "A tool that searches for patterns"),
    ]
    filter = build_filter(tools)
    assert_equal 2, filter.tool_count

    result = filter.filter("search for patterns")
    # May be nil or an array
    assert(result.nil? || result.is_a?(Array))
  end

  def test_filter_with_scores_returns_hashes
    filter = build_filter
    results = filter.filter_with_scores("browse a web page")

    results.each do |entry|
      assert_kind_of Hash, entry
      assert entry.key?(:name), "Each entry should have :name"
      assert entry.key?(:score), "Each entry should have :score"
      assert_kind_of String, entry[:name]
      assert_kind_of Float, entry[:score]
      assert entry[:score] >= 0.0 && entry[:score] <= 1.0
    end
  end

  def test_scores_sorted_descending
    filter = build_filter
    results = filter.filter_with_scores("execute ruby code and run calculations")

    scores = results.map { |r| r[:score] }
    assert_equal scores, scores.sort.reverse, "Scores should be in descending order"
  end

  def test_error_in_filter_returns_empty_array_without_raising
    # Previously the rescue block called `logger.warn` which would raise
    # NoMethodError. This test verifies the error path returns [] gracefully
    # using Kernel#warn instead.
    filter = build_filter
    Classifier::TFIDF.any_instance.stubs(:fit).raises(StandardError, "classifier error")
    result = filter.filter_with_scores("some prompt")
    assert_equal [], result
  end
end
