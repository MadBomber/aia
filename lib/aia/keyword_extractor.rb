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

    # Compute per-entry distinctive keywords using TF-IDF.
    # Words that appear in many entries get low IDF (they're common noise).
    # Words that appear rarely but frequently within one entry rank highest.
    #
    # @param corpus [Hash{String => String}] name => description text
    # @param max [Integer] max keywords to return per entry
    # @return [Hash{String => Set<String>}] name => distinctive keyword Set
    def distinctive_keywords(corpus, max: 8)
      # Tokenize each entry
      tokenized = corpus.transform_values { |text| tokenize(text).to_a }

      total = corpus.size.to_f

      # Document frequency: how many entries contain each word
      doc_freq = Hash.new(0)
      tokenized.each_value { |tokens| tokens.uniq.each { |w| doc_freq[w] += 1 } }

      tokenized.transform_values do |tokens|
        tf = tokens.tally
        size = [tokens.size, 1].max.to_f

        scored = tf.map do |word, count|
          idf   = Math.log((total + 1.0) / (doc_freq[word] + 1.0))
          score = (count / size) * idf
          [word, score]
        end

        top = scored.sort_by { |_, s| -s }.first(max).map(&:first)
        Set.new(top)
      end
    end
  end
end
