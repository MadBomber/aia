# frozen_string_literal: true

# lib/aia/tool_filter/wordnet_expander.rb
#
# Expands tool description text with WordNet synonyms at index time.
# Uses the `wn` CLI from `brew install wordnet`.
#
# Expansion is applied once per build_index call (not to user queries).
# Results are cached in-process so each unique word is only looked up once.
# If `wn` is not installed, expand() is a no-op that returns the original text.
#
# WordNet POS queried: nouns (-synsn) and verbs (-synsv).
# Multi-word synonyms (containing spaces or underscores) are excluded.
# Words shorter than MIN_WORD_LENGTH are excluded (filters stop words).

require 'shellwords'

module AIA
  class ToolFilter
    module WordNetExpander
      MIN_WORD_LENGTH = 4

      @cache          = {}
      @cache_mutex    = Mutex.new
      @available      = nil
      @available_mutex = Mutex.new

      class << self
        # Returns true if the `wn` executable is on PATH.
        # Result is cached for the process lifetime.
        def available?
          @available_mutex.synchronize do
            return @available unless @available.nil?
            @available = system("which wn", out: File::NULL, err: File::NULL) ? true : false
          end
        end

        # Expand text by appending synonyms for each content word.
        # Returns the original text unchanged if wn is unavailable.
        #
        # @param text [String] raw tool description text
        # @return [String] original text plus appended synonym terms
        def expand(text)
          return text unless available?

          words     = text.downcase.scan(/[a-z]{#{MIN_WORD_LENGTH},}/).uniq
          new_terms = words.flat_map { |w| synonyms_for(w) }
                           .uniq
                           .reject { |w| words.include?(w) }

          new_terms.empty? ? text : "#{text} #{new_terms.join(' ')}"
        end

        # Return synonyms for a single word from WordNet (nouns + verbs).
        # Does not include the word itself. Returns [] if not found.
        # Results are cached per-word for the process lifetime.
        #
        # @param word [String] lowercase word to look up
        # @return [Array<String>] synonym strings, single-word only
        def synonyms_for(word)
          # fast path: already cached
          @cache_mutex.synchronize { return @cache[word] if @cache.key?(word) }

          syns = (query_wn(word, 'n') + query_wn(word, 'v'))
                   .uniq
                   .reject { |w| w == word }

          # write path: first writer wins; read-back in same lock so clear_cache!
          # between write and read cannot cause nil to escape
          @cache_mutex.synchronize do
            @cache[word] = syns unless @cache.key?(word)
            @cache[word]
          end
        rescue StandardError
          []
        end

        # Wipe the in-process synonym cache. Used between tests.
        def clear_cache!
          @cache_mutex.synchronize { @cache.clear }
        end

        private

        # Shell out to `wn word -syns{pos}` and parse the synset lines.
        #
        # @param word [String] word to look up
        # @param pos  [String] part of speech: 'n' (noun) or 'v' (verb)
        # @return [Array<String>] single-word synonyms
        def query_wn(word, pos)
          output = `wn #{Shellwords.escape(word)} -syns#{pos} 2>/dev/null`
          parse_synsets(output)
        rescue StandardError
          []
        end

        # Parse synset lines from `wn` output.
        #
        # Synset lines start with a lowercase letter (no leading whitespace)
        # and contain comma-separated synonym words. Hypernym/relative lines
        # start with whitespace or contain '=>' and are skipped.
        #
        # @param output [String] raw output from `wn`
        # @return [Array<String>] unique single-word synonym strings
        def parse_synsets(output)
          output.lines.flat_map do |line|
            next [] unless line.match?(/\A[a-z]/)
            next [] if line.include?("=>")

            line.chomp.split(/,\s*/).map(&:strip).select do |word|
              word.length >= MIN_WORD_LENGTH &&
                !word.include?(' ') &&
                !word.include?('_') &&
                word.match?(/\A[a-z]+\z/)
            end
          end.uniq
        end
      end
    end
  end
end
