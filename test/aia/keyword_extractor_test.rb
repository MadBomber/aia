# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/aia/keyword_extractor'

class KeywordExtractorTokenizeTest < Minitest::Test
  def test_returns_a_set
    result = AIA::KeywordExtractor.tokenize("hello world")
    assert_instance_of Set, result
  end

  def test_lowercases_all_tokens
    result = AIA::KeywordExtractor.tokenize("Computer SYSTEM")
    assert_includes result, "computer"
    assert_includes result, "system"
  end

  def test_removes_stopwords
    result = AIA::KeywordExtractor.tokenize("tell me about the computer")
    refute_includes result, "the"
    refute_includes result, "me"
    refute_includes result, "about"
  end

  def test_removes_short_words
    result = AIA::KeywordExtractor.tokenize("go do it now")
    refute_includes result, "go"
    refute_includes result, "do"
    refute_includes result, "it"
  end

  def test_splits_underscores
    result = AIA::KeywordExtractor.tokenize("computer_tool disk_reader")
    assert_includes result, "computer"
    assert_includes result, "tool"
    assert_includes result, "disk"
    assert_includes result, "reader"
  end

  def test_strips_punctuation
    result = AIA::KeywordExtractor.tokenize("read/write files. fast!")
    assert_includes result, "read"
    assert_includes result, "write"
    assert_includes result, "files"
    assert_includes result, "fast"
  end

  def test_empty_string_returns_empty_set
    result = AIA::KeywordExtractor.tokenize("")
    assert_empty result
  end

  def test_keeps_meaningful_words
    result = AIA::KeywordExtractor.tokenize("executes SQL queries on the database")
    assert_includes result, "executes"
    assert_includes result, "sql"
    assert_includes result, "queries"
    assert_includes result, "database"
  end
end
