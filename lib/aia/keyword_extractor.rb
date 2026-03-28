# frozen_string_literal: true

# lib/aia/keyword_extractor.rb
#
# Shared tokenizer for keyword-overlap tool routing.
# Used by DynamicRuleBuilder (at startup, to build per-tool TF-IDF keyword sets)
# and by FactAsserter (at each turn, to extract prompt keywords for rule matching).

require 'set'

module AIA
  module KeywordExtractor
    STOPWORDS = Set.new(%w[
      a an the is are was were be been being have has had
      do does did will would could should may might shall can
      of to for in on at by with from about as into through
      during until against among despite towards upon this that
      these those and or but not no nor so all each every any
      some few much many more most other such only same just
      its it them their they we you use uses used using via per
      get set let put run add
    ]).freeze

    module_function

    # Tokenize text into a Set of normalized, meaningful words.
    # Splits on whitespace, underscores, slashes, and hyphens.
    # Removes stopwords and words shorter than 3 characters.
    #
    # @param text [String]
    # @return [Set<String>]
    def tokenize(text)
      Set.new(
        text.to_s
            .downcase
            .gsub(/[^a-z0-9\s_\-\/]/, ' ')
            .split(/[\s_\-\/]+/)
            .select { |w| w.length >= 3 }
            .reject { |w| STOPWORDS.include?(w) }
      )
    end
  end
end
