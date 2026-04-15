# frozen_string_literal: true
# test/aia/tool_filter/sqlite_vec_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'
require_relative '../../../lib/aia/tool_filter/embedding_model_loader'
require_relative '../../../lib/aia/tool_filter/sqlite_vec'

class ToolFilterSqliteVecTest < Minitest::Test
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

  def build_filter(tools = build_tools, top_k: 30, similarity_threshold: 0.05,
                   db_dir: nil, load_db: false, save_db: false)
    fact_asserter = AIA::FactAsserter.new
    filter = AIA::ToolFilter::SqliteVec.new(
      tools: tools, fact_asserter: fact_asserter,
      top_k: top_k, similarity_threshold: similarity_threshold,
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
  ensure
    filter&.cleanup
  end

  def test_empty_tools_builds_empty_index
    filter = build_filter([])
    assert_equal 0, filter.tool_count
  ensure
    filter&.cleanup
  end

  def test_label
    filter = build_filter
    assert_equal "SqVec", filter.label
  ensure
    filter&.cleanup
  end

  def test_prep_captures_timing
    filter = build_filter
    assert filter.prep_ms > 0.0
  ensure
    filter&.cleanup
  end

  def test_available_after_prep
    filter = build_filter
    assert filter.available?
  ensure
    filter&.cleanup
  end

  def test_not_available_with_empty_tools
    filter = build_filter([])
    refute filter.available?
  ensure
    filter&.cleanup
  end

  def test_persistable
    filter = build_filter
    assert filter.persistable?
  ensure
    filter&.cleanup
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
  ensure
    filter&.cleanup
  end

  def test_filter_returns_tool_names
    filter = build_filter
    names = filter.filter("run a SQL query to find users")
    assert(names.nil? || names.is_a?(Array))
    names&.each { |n| assert_kind_of String, n }
  ensure
    filter&.cleanup
  end

  def test_top_k_cap
    filter = build_filter(top_k: 3, similarity_threshold: 0.0)
    results = filter.filter("tools for everything")
    assert results.nil? || results.size <= 3,
      "Should cap at top_k (got #{results&.size})"
  ensure
    filter&.cleanup
  end

  # =========================================================================
  # Edge cases
  # =========================================================================

  def test_nil_prompt_returns_nil
    filter = build_filter
    assert_nil filter.filter(nil)
  ensure
    filter&.cleanup
  end

  def test_empty_prompt_returns_nil
    filter = build_filter
    assert_nil filter.filter("")
    assert_nil filter.filter("   ")
  ensure
    filter&.cleanup
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
  ensure
    filter&.cleanup
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
  ensure
    filter&.cleanup
  end

  def test_scores_sorted_descending
    filter = build_filter
    results = filter.filter_with_scores("execute ruby code and run calculations")

    scores = results.map { |r| r[:score] }
    assert_equal scores, scores.sort.reverse, "Scores should be in descending order"
  ensure
    filter&.cleanup
  end

  def test_cleanup_closes_database
    filter = build_filter
    db = filter.instance_variable_get(:@db)
    assert db, "Database should exist before cleanup"

    filter.cleanup
    assert_nil filter.instance_variable_get(:@db), "Database should be nil after cleanup"
  end

  # =========================================================================
  # Persistence (--save / --load)
  # =========================================================================

  def test_save_persists_database_file
    Dir.mktmpdir("sqvec_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, save_db: true)
      assert_equal 7, filter.tool_count

      db_path = File.join(tmpdir, "sqlite_vec_tool_filter.db")
      assert File.exist?(db_path), "Database file should exist after save"
      assert File.size(db_path) > 0, "Database file should not be empty"
    ensure
      filter&.cleanup
    end
  end

  def test_save_includes_tool_meta_table
    Dir.mktmpdir("sqvec_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, save_db: true)
      filter.cleanup

      # Open the saved DB directly and verify tool_meta table
      db_path = File.join(tmpdir, "sqlite_vec_tool_filter.db")
      db = SQLite3::Database.new(db_path)
      rows = db.execute("SELECT rowid, name, description FROM tool_meta ORDER BY rowid")
      assert_equal 7, rows.size
      assert_equal "file_search", rows[0][1]
      db.close
    end
  end

  def test_load_restores_from_persisted_database
    Dir.mktmpdir("sqvec_persist_test") do |tmpdir|
      # First: build and save
      filter1 = build_filter(db_dir: tmpdir, save_db: true)
      assert_equal 7, filter1.tool_count
      filter1.cleanup

      # Second: load from persisted data
      filter2 = build_filter(db_dir: tmpdir, load_db: true)
      assert_equal 7, filter2.tool_count
      assert filter2.available?

      # Verify loaded filter can query
      results = filter2.filter_with_scores("search for a file")
      refute_empty results, "Loaded filter should return results"
      names = results.map { |r| r[:name] }
      assert_includes names, "file_search"
    ensure
      filter2&.cleanup
    end
  end

  def test_load_with_save_builds_and_persists_when_no_cache
    Dir.mktmpdir("sqvec_persist_test") do |tmpdir|
      # Load + save with no existing cache: should build fresh and save
      filter = build_filter(db_dir: tmpdir, load_db: true, save_db: true)
      assert_equal 7, filter.tool_count

      db_path = File.join(tmpdir, "sqlite_vec_tool_filter.db")
      assert File.exist?(db_path), "Should save when load finds no cache"
    ensure
      filter&.cleanup
    end
  end

  def test_load_without_persisted_data_falls_back_to_build
    Dir.mktmpdir("sqvec_persist_test") do |tmpdir|
      # Load with no persisted data: should build in-memory from scratch
      filter = build_filter(db_dir: tmpdir, load_db: true)
      assert_equal 7, filter.tool_count
      assert filter.available?

      results = filter.filter_with_scores("run SQL queries")
      refute_empty results
    ensure
      filter&.cleanup
    end
  end

  def test_save_file_survives_cleanup
    Dir.mktmpdir("sqvec_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, save_db: true)
      db_path = File.join(tmpdir, "sqlite_vec_tool_filter.db")
      assert File.exist?(db_path)

      filter.cleanup

      # File should still exist after cleanup (handle closed, file remains)
      assert File.exist?(db_path), "Database file should survive cleanup"
    end
  end

  def test_without_persistence_uses_in_memory
    filter = build_filter
    db = filter.instance_variable_get(:@db)
    assert db, "Database should exist"
    # In-memory databases have filename ":memory:" or empty
    # Just verify it works without db_dir
    assert_equal 7, filter.tool_count
  ensure
    filter&.cleanup
  end

  # =========================================================================
  # Rowid mapping (4.3)
  # =========================================================================

  def test_tool_index_is_populated_after_prep
    filter = build_filter
    index = filter.instance_variable_get(:@tool_index)
    refute_empty index, "tool_index should be populated after prep"
    assert_equal 7, index.size
    index.each do |rowid, entry|
      assert_kind_of Integer, rowid
      assert entry.key?(:name)
      assert entry.key?(:description)
    end
  ensure
    filter&.cleanup
  end

  def test_tool_index_lookup_is_stable_across_reinsertion
    # Simulate building a new filter with the same tools — rowid mapping should
    # still resolve names correctly even if @tool_entries order could vary.
    filter = build_filter
    index = filter.instance_variable_get(:@tool_index)
    results = filter.filter_with_scores("search for a file named config.yml")
    names_via_filter = results.map { |r| r[:name] }
    names_via_index  = index.values.map { |e| e[:name] }
    assert(names_via_filter.all? { |n| names_via_index.include?(n) },
      "All filtered tool names must exist in tool_index")
  ensure
    filter&.cleanup
  end

  def test_uses_embedding_model_loader_mixin
    assert AIA::ToolFilter::SqliteVec.include?(AIA::ToolFilter::EmbeddingModelLoader),
      "SqliteVec should include EmbeddingModelLoader"
  end
end
