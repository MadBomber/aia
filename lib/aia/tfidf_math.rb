# frozen_string_literal: true

# lib/aia/tfidf_math.rb
#
# Pure TF-IDF vector math shared by SimilarityScorer and ToolFilter::TFIDF.
# Kept dependency-free and stateless so both callers (and tests) can use it
# in isolation.

module AIA
  module TFIDFMath
    module_function

    # Cosine similarity between two TF-IDF hash vectors.
    #
    # @param a [Hash{Symbol => Float}]
    # @param b [Hash{Symbol => Float}]
    # @return [Float] 0.0..1.0
    def cosine_similarity(a, b)
      all_keys = a.keys | b.keys
      dot   = all_keys.sum { |k| (a[k] || 0.0) * (b[k] || 0.0) }
      mag_a = Math.sqrt(a.values.sum { |v| v**2 })
      mag_b = Math.sqrt(b.values.sum { |v| v**2 })
      return 0.0 if mag_a.zero? || mag_b.zero?
      (dot / (mag_a * mag_b)).clamp(0.0, 1.0)
    end
  end
end
