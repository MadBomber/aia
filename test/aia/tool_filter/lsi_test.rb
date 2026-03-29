# frozen_string_literal: true
# test/aia/tool_filter/lsi_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'

class ToolFilterLSITest < Minitest::Test
  # =========================================================================
  # Test helpers — mock tool objects
  # =========================================================================

  MockTool = Struct.new(:name, :description)

  # Disable WordNet expansion for LSI unit tests so the LSI semantic space
  # matches what these tests were written against.  The wiring itself is
  # validated in wordnet_expansion_wiring_test.rb.
  def setup
    AIA::ToolFilter::WordNetExpander.stubs(:available?).returns(false)
  end

  def teardown
    AIA::ToolFilter::WordNetExpander.reset_for_testing!
  end

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

  def build_filter(tools = build_tools, max_tools: 30, similarity_threshold: 0.001,
                   db_dir: nil, load_db: false, save_db: false)
    fact_asserter = AIA::FactAsserter.new
    filter = AIA::ToolFilter::LSI.new(
      tools: tools, fact_asserter: fact_asserter,
      max_tools: max_tools, similarity_threshold: similarity_threshold,
      db_dir: db_dir, load_db: load_db, save_db: save_db
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
    assert_equal "LSI", filter.label
  end

  def test_prep_captures_timing
    filter = build_filter
    assert filter.prep_ms >= 0.0
  end

  def test_available_after_prep
    filter = build_filter
    assert filter.available?
  end

  def test_not_available_with_empty_tools
    filter = build_filter([])
    refute filter.available?
  end

  def test_persistable
    filter = build_filter
    assert filter.persistable?
  end

  # =========================================================================
  # Filtering
  # =========================================================================

  def test_relevant_tools_ranked_higher
    filter = build_filter
    results = filter.filter_with_scores("search for a file named config.yml")

    names = results.map { |r| r[:name] }
    assert_includes names, "file_search", "file_search should match a file search prompt"

    file_entry = results.find { |r| r[:name] == "file_search" }
    assert file_entry[:score] > 0.0 if file_entry
  end

  def test_database_query_matches
    filter = build_filter
    results = filter.filter_with_scores("query the users table in the database")

    names = results.map { |r| r[:name] }
    assert_includes names, "database_query"
  end

  def test_filter_returns_tool_names
    filter = build_filter
    names = filter.filter("run a SQL query to find users")
    assert(names.nil? || names.is_a?(Array))
    names&.each { |n| assert_kind_of String, n }
  end

  def test_max_tools_cap
    filter = build_filter(max_tools: 3, similarity_threshold: 0.0)
    results = filter.filter_with_scores("tools for everything")
    assert results.size <= 3,
      "Should cap at max_tools (got #{results.size})"
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
    end
  end

  def test_scores_sorted_descending
    filter = build_filter
    results = filter.filter_with_scores("execute ruby code and run calculations")

    scores = results.map { |r| r[:score] }
    assert_equal scores, scores.sort.reverse, "Scores should be in descending order"
  end

  # =========================================================================
  # Persistence (--save / --load)
  # =========================================================================

  def test_save_persists_marshal_file
    Dir.mktmpdir("lsi_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, save_db: true)
      assert_equal 7, filter.tool_count

      marshal_path = File.join(tmpdir, "lsi_tool_filter.marshal")
      assert File.exist?(marshal_path), "Marshal file should exist after save"
      assert File.size(marshal_path) > 0
    end
  end

  def test_load_restores_from_persisted_index
    Dir.mktmpdir("lsi_persist_test") do |tmpdir|
      # First: build and save
      filter1 = build_filter(db_dir: tmpdir, save_db: true)
      assert_equal 7, filter1.tool_count

      # Second: load from persisted data
      filter2 = build_filter(db_dir: tmpdir, load_db: true)
      assert_equal 7, filter2.tool_count
      assert filter2.available?

      # Verify loaded filter can query
      results = filter2.filter_with_scores("search for a file")
      refute_empty results, "Loaded filter should return results"
      names = results.map { |r| r[:name] }
      assert_includes names, "file_search"
    end
  end

  def test_load_with_save_builds_and_persists_when_no_cache
    Dir.mktmpdir("lsi_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, load_db: true, save_db: true)
      assert_equal 7, filter.tool_count

      marshal_path = File.join(tmpdir, "lsi_tool_filter.marshal")
      assert File.exist?(marshal_path), "Should save when load finds no cache"
    end
  end

  def test_load_without_persisted_data_falls_back_to_build
    Dir.mktmpdir("lsi_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, load_db: true)
      assert_equal 7, filter.tool_count
      assert filter.available?

      results = filter.filter_with_scores("run SQL queries")
      refute_empty results
    end
  end
end
