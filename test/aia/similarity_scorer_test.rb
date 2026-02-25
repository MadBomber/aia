# frozen_string_literal: true
# test/aia/similarity_scorer_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class SimilarityScorerTest < Minitest::Test
  # =========================================================================
  # Edge cases
  # =========================================================================

  def test_empty_array_returns_empty
    assert_equal [], AIA::SimilarityScorer.score([])
  end

  def test_single_response_returns_array_of_nil
    result = AIA::SimilarityScorer.score(["Hello world"])
    assert_equal 1, result.size
    assert_nil result[0]
  end

  def test_blank_reference_returns_nils
    result = AIA::SimilarityScorer.score(["", "Some text here"])
    assert_equal 2, result.size
  end

  # =========================================================================
  # Similarity scoring
  # =========================================================================

  def test_identical_responses_score_one
    text = "The quick brown fox jumps over the lazy dog"
    result = AIA::SimilarityScorer.score([text, text])

    assert_nil result[0], "First model should be nil (reference)"
    assert_in_delta 1.0, result[1], 0.01, "Identical text should score ~1.0"
  end

  def test_similar_responses_score_high
    ref = "Ruby is a dynamic, open-source programming language with a focus on simplicity and productivity."
    similar = "Ruby is a dynamic programming language that is open source and focuses on simplicity and developer productivity."
    result = AIA::SimilarityScorer.score([ref, similar])

    assert_nil result[0]
    assert result[1] > 0.5, "Similar responses should have high similarity (got #{result[1]})"
  end

  def test_dissimilar_responses_score_low
    ref = "Ruby is a dynamic programming language created by Yukihiro Matsumoto."
    different = "The weather forecast calls for rain tomorrow with temperatures dropping below freezing overnight."
    result = AIA::SimilarityScorer.score([ref, different])

    assert_nil result[0]
    assert result[1] < 0.3, "Dissimilar responses should have low similarity (got #{result[1]})"
  end

  def test_multiple_models_all_scored_against_first
    ref = "Machine learning is a subset of artificial intelligence that enables systems to learn from data."
    similar = "Machine learning is part of artificial intelligence where systems learn from data automatically."
    different = "The stock market closed higher today driven by strong earnings reports from technology companies."

    result = AIA::SimilarityScorer.score([ref, similar, different])

    assert_equal 3, result.size
    assert_nil result[0], "Reference model should be nil"
    assert result[1] > result[2], "Similar response should score higher than dissimilar (#{result[1]} vs #{result[2]})"
  end

  def test_returns_floats_between_zero_and_one
    texts = [
      "The Ruby programming language was designed for programmer happiness.",
      "Python is widely used in data science and machine learning applications.",
      "Go was created at Google for building scalable network services."
    ]
    result = AIA::SimilarityScorer.score(texts)

    result.each_with_index do |score, i|
      next if i == 0 # reference is nil
      assert_kind_of Float, score
      assert score >= 0.0 && score <= 1.0, "Score should be 0..1 (got #{score})"
    end
  end

  # =========================================================================
  # Error handling
  # =========================================================================

  def test_handles_nil_response_text_gracefully
    result = AIA::SimilarityScorer.score(["Hello world", nil])
    assert_equal 2, result.size
  end
end
