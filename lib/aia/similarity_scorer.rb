# frozen_string_literal: true

# lib/aia/similarity_scorer.rb
#
# Computes TF-IDF cosine similarity between LLM responses.
# Uses the classifier gem's TF-IDF vectorizer with Porter stemming
# so that paraphrased responses ("focused" / "focuses") score high.

require 'classifier'
require_relative 'tfidf_math'

module AIA
  class SimilarityScorer
    # Compute pairwise similarity of each response against the first.
    #
    # @param responses [Array<String>] ordered response texts (first is reference)
    # @return [Array<Float, nil>] similarity scores (nil for first, 0.0..1.0 for rest)
    # :reek:TooManyStatements -- guarded scoring: two early-out shapes, TF-IDF fit/transform, pairwise map, rescue fallback
    def self.score(responses)
      count = responses.size
      return Array.new(count) if count < 2

      texts = responses.map { |r| r.to_s.strip }
      return Array.new(count) if texts.first.empty?

      tfidf = Classifier::TFIDF.new
      tfidf.fit(texts)
      vectors = texts.map { |t| tfidf.transform(t) }

      vectors.each_with_index.map do |_vec, i|
        if i.zero?
          nil # reference model -- no comparison
        else
          AIA::TFIDFMath.cosine_similarity(vectors[0], vectors[i])
        end
      end
    rescue StandardError
      Array.new(count)
    end
  end
end
