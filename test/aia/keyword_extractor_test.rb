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

class KeywordExtractorTfIdfTest < Minitest::Test
  def test_returns_hash_keyed_by_name
    corpus = { "computer_tool" => "control the computer desktop screen",
               "disk_tool"     => "read and write files on disk" }
    result = AIA::KeywordExtractor.distinctive_keywords(corpus)
    assert_instance_of Hash, result
    assert result.key?("computer_tool")
    assert result.key?("disk_tool")
  end

  def test_each_value_is_a_set
    corpus = { "computer_tool" => "control the computer desktop screen",
               "disk_tool"     => "read and write files on disk" }
    result = AIA::KeywordExtractor.distinctive_keywords(corpus)
    result.each_value { |v| assert_instance_of Set, v }
  end

  def test_distinctive_term_ranks_high_for_its_tool
    corpus = {
      "computer_tool" => "control the computer desktop screen application",
      "disk_tool"     => "read and write files on disk directory",
      "browser_tool"  => "open url in browser navigate web page"
    }
    result = AIA::KeywordExtractor.distinctive_keywords(corpus)
    assert_includes result["computer_tool"], "computer"
    assert_includes result["disk_tool"],     "disk"
    assert_includes result["browser_tool"],  "browser"
  end

  def test_common_word_excluded_from_distinctive_set
    corpus = {
      "computer_tool" => "computer desktop screen application keyboard mouse",
      "disk_tool"     => "disk files read write directory path",
      "browser_tool"  => "browser url navigate web page html"
    }
    result = AIA::KeywordExtractor.distinctive_keywords(corpus)
    refute_equal result["computer_tool"], result["disk_tool"]
    refute_equal result["disk_tool"],     result["browser_tool"]
  end

  def test_single_tool_corpus_returns_all_tokens
    corpus = { "my_tool" => "reads and writes the local filesystem" }
    result = AIA::KeywordExtractor.distinctive_keywords(corpus)
    assert result["my_tool"].size > 0
  end

  def test_max_keyword_count_is_respected
    corpus = {
      "a" => "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda",
      "b" => "one two three four five six seven eight nine ten eleven twelve"
    }
    result = AIA::KeywordExtractor.distinctive_keywords(corpus, max: 5)
    result.each_value { |kws| assert kws.size <= 5, "Expected <= 5 keywords, got #{kws.size}" }
  end
end
