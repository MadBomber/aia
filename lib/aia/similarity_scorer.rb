# frozen_string_literal: true

# lib/aia/similarity_scorer.rb
#
# Computes TF-IDF cosine similarity between LLM responses.
# Uses the classifier gem's TF-IDF vectorizer with Porter stemming
# so that paraphrased responses ("focused" / "focuses") score high.

require 'classifier'

module AIA
  class SimilarityScorer
    # Compute pairwise similarity of each response against the first.
    #
    # @param responses [Array<String>] ordered response texts (first is reference)
    # @return [Array<Float, nil>] similarity scores (nil for first, 0.0..1.0 for rest)
    def self.score(responses)
      return Array.new(responses.size) if responses.size < 2

      texts = responses.map { |r| r.to_s.strip }
      return Array.new(responses.size) if texts.first.empty?

      tfidf = Classifier::TFIDF.new
      tfidf.fit(texts)
      vectors = texts.map { |t| tfidf.transform(t) }

      vectors.each_with_index.map do |_vec, i|
        if i == 0
          nil # reference model -- no comparison
        else
          cosine_similarity(vectors[0], vectors[i])
        end
      end
    rescue StandardError
      Array.new(responses.size)
    end

    # Cosine similarity between two TF-IDF hash vectors.
    #
    # @param a [Hash{Symbol => Float}]
    # @param b [Hash{Symbol => Float}]
    # @return [Float] 0.0..1.0
    def self.cosine_similarity(a, b)
      all_keys = a.keys | b.keys
      dot   = all_keys.sum { |k| (a[k] || 0.0) * (b[k] || 0.0) }
      mag_a = Math.sqrt(a.values.sum { |v| v**2 })
      mag_b = Math.sqrt(b.values.sum { |v| v**2 })
      return 0.0 if mag_a.zero? || mag_b.zero?
      (dot / (mag_a * mag_b)).clamp(0.0, 1.0)
    end
    private_class_method :cosine_similarity
  end
end
