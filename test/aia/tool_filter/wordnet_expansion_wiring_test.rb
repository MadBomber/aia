# frozen_string_literal: true
# test/aia/tool_filter/wordnet_expansion_wiring_test.rb
#
# Verifies that each filter calls WordNetExpander.expand during build_index.
# Uses Mocha to stub expand so the test doesn't depend on wn being installed.

require_relative '../../test_helper'
require_relative '../../../lib/aia'

class WordNetExpansionWiringTest < Minitest::Test
  MockToolWiring = Struct.new(:name, :description, :parameters)

  # Fixed expansion string returned by the stub regardless of input.
  # Must contain "EXPANDED" so all non-TFIDF assertions pass,
  # and must contain words that stem to something stable for TFIDF.
  FIXED_EXPANSION = "search find files EXPANDED"

  def setup
    @fa = AIA::FactAsserter.new
    AIA::ToolFilter::WordNetExpander.stubs(:available?).returns(true)
    # Mocha 3.x block passed to stubs() is a side-effect block, not a return-value block.
    # Use .returns for a deterministic return value.
    AIA::ToolFilter::WordNetExpander.stubs(:expand).returns(FIXED_EXPANSION)
  end

  def teardown
    AIA::ToolFilter::WordNetExpander.clear_cache!
    AIA::ToolFilter::EmbeddingModelLoader._cache.clear
  end

  def tool(name:, description:)
    MockToolWiring.new(name, description, {})
  end

  def test_tfidf_build_index_uses_expanded_text
    t = tool(name: "search", description: "find files")
    filter = AIA::ToolFilter::TFIDF.new(tools: [t], fact_asserter: @fa)
    filter.prep

    entry = filter.instance_variable_get(:@tool_entries).first
    # FIXED_EXPANSION = "search find files EXPANDED"
    # After Porter stemming, "EXPANDED" -> "expand", "search" -> "search", etc.
    # Verify that the expansion text was used (stemmed "expand" from "EXPANDED" is present).
    assert entry[:description].include?("expand"),
           "Expected 'expand' (stemmed EXPANDED) in TFIDF indexed description. Got: #{entry[:description].inspect}"
  end

  def test_lsi_build_index_uses_expanded_text
    t = tool(name: "search", description: "find files")
    filter = AIA::ToolFilter::LSI.new(tools: [t], fact_asserter: @fa)
    filter.prep

    entry = filter.instance_variable_get(:@tool_entries).first
    assert entry[:description].include?("EXPANDED"),
           "Expected 'EXPANDED' in LSI indexed description. Got: #{entry[:description].inspect}"
  end

  def test_zvec_build_index_uses_expanded_text
    t = tool(name: "search", description: "find files")

    mock_model = mock('embedding_model')
    mock_model.stubs(:call).returns([0.1] * 384)
    Informers.stubs(:pipeline).returns(mock_model)
    AIA::ToolFilter::EmbeddingModelLoader._cache.clear
    AIA::ToolFilter::EmbeddingModelLoader._cache[AIA::ToolFilter::Zvec::MODEL_NAME] = mock_model

    filter = AIA::ToolFilter::Zvec.new(tools: [t], fact_asserter: @fa)

    # Stub Zvec internals to avoid actual HNSW collection creation
    mock_collection = mock('zvec_collection')
    mock_collection.stubs(:insert).returns(["OK"])
    mock_collection.stubs(:flush)
    ::Zvec::Collection.stubs(:create_and_open).returns(mock_collection)

    filter.prep

    entry = filter.instance_variable_get(:@tool_entries).first
    assert entry[:description].include?("EXPANDED"),
           "Expected 'EXPANDED' in Zvec indexed description. Got: #{entry[:description].inspect}"
  end

  def test_sqlite_vec_build_index_uses_expanded_text
    t = tool(name: "search", description: "find files")

    mock_model = mock('embedding_model')
    mock_model.stubs(:call).returns([0.1] * 384)
    Informers.stubs(:pipeline).returns(mock_model)
    AIA::ToolFilter::EmbeddingModelLoader._cache.clear
    AIA::ToolFilter::EmbeddingModelLoader._cache[AIA::ToolFilter::SqliteVec::MODEL_NAME] = mock_model

    filter = AIA::ToolFilter::SqliteVec.new(tools: [t], fact_asserter: @fa)
    filter.prep

    entry = filter.instance_variable_get(:@tool_entries).first
    assert entry[:description].include?("EXPANDED"),
           "Expected 'EXPANDED' in SqliteVec indexed description. Got: #{entry[:description].inspect}"
  end
end
