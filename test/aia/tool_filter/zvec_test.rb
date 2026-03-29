# frozen_string_literal: true
# test/aia/tool_filter/zvec_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'

class ToolFilterZvecTest < Minitest::Test
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
    filter = AIA::ToolFilter::Zvec.new(
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
    assert_equal "Zvec", filter.label
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

  def test_cleanup_removes_tmpdir
    filter = build_filter
    tmpdir = filter.instance_variable_get(:@tmpdir)
    assert Dir.exist?(tmpdir), "Tmpdir should exist before cleanup" if tmpdir

    filter.cleanup
    refute Dir.exist?(tmpdir), "Tmpdir should be removed after cleanup" if tmpdir
  end

  # =========================================================================
  # Persistence (--save / --load)
  # =========================================================================

  def test_save_persists_collection_and_metadata
    Dir.mktmpdir("zvec_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, save_db: true)
      assert_equal 7, filter.tool_count

      persist_dir = File.join(tmpdir, "zvec_tool_filter")
      assert Dir.exist?(persist_dir), "Persistent directory should exist after save"

      meta_path = File.join(persist_dir, "tool_entries.json")
      assert File.exist?(meta_path), "tool_entries.json should exist after save"

      meta = JSON.parse(File.read(meta_path))
      entries = meta.key?("entries") ? meta["entries"] : meta
      assert_equal 7, entries.size

      col_path = File.join(persist_dir, "collection")
      assert Dir.exist?(col_path), "Collection directory should exist after save"
    ensure
      filter&.cleanup
    end
  end

  def test_load_restores_from_persisted_collection
    Dir.mktmpdir("zvec_persist_test") do |tmpdir|
      # First: build and save
      filter1 = build_filter(db_dir: tmpdir, save_db: true)
      assert_equal 7, filter1.tool_count
      filter1.cleanup  # release collection lock

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
    Dir.mktmpdir("zvec_persist_test") do |tmpdir|
      # Load + save with no existing cache: should build fresh and save
      filter = build_filter(db_dir: tmpdir, load_db: true, save_db: true)
      assert_equal 7, filter.tool_count

      persist_dir = File.join(tmpdir, "zvec_tool_filter")
      assert Dir.exist?(persist_dir), "Should save when load finds no cache"
    ensure
      filter&.cleanup
    end
  end

  def test_load_without_persisted_data_falls_back_to_build
    Dir.mktmpdir("zvec_persist_test") do |tmpdir|
      # Load with no persisted data: should build from scratch
      filter = build_filter(db_dir: tmpdir, load_db: true)
      assert_equal 7, filter.tool_count
      assert filter.available?

      results = filter.filter_with_scores("run SQL queries")
      refute_empty results
    ensure
      filter&.cleanup
    end
  end

  def test_save_does_not_remove_persistent_dir_on_cleanup
    Dir.mktmpdir("zvec_persist_test") do |tmpdir|
      filter = build_filter(db_dir: tmpdir, save_db: true)
      persist_dir = File.join(tmpdir, "zvec_tool_filter")
      assert Dir.exist?(persist_dir)

      filter.cleanup

      # Persistent dir should survive cleanup (only tmpdir is removed)
      assert Dir.exist?(persist_dir), "Persistent directory should survive cleanup"
    end
  end

  def test_uses_embedding_model_loader_mixin
    assert AIA::ToolFilter::Zvec.include?(AIA::ToolFilter::EmbeddingModelLoader),
      "Zvec should include EmbeddingModelLoader"
  end
end
