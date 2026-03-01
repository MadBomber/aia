# frozen_string_literal: true

# lib/aia/tfidf_tool_filter.rb
#
# TF-IDF based tool filtering for A/B testing against KBS rule-based filtering.
# Built once at session start from all tool descriptions (local + MCP).
# Per-turn: scores user prompt against each tool's description via cosine
# similarity and returns tool names above threshold, capped at max_tools.

require 'classifier'

module AIA
  class TfidfToolFilter
    DEFAULT_THRESHOLD = 0.05
    DEFAULT_MAX_TOOLS = 30

    attr_reader :tool_count

    # Build the TF-IDF index from all available tools.
    #
    # @param tools [Array] tool classes/objects with .name and .description
    # @param fact_asserter [FactAsserter] used for tool_name/tool_description extraction
    # @param threshold [Float] minimum cosine similarity to include a tool (default 0.05)
    # @param max_tools [Integer] maximum tools to return per turn (default 30)
    def initialize(tools, fact_asserter, threshold: DEFAULT_THRESHOLD, max_tools: DEFAULT_MAX_TOOLS)
      @fact_asserter = fact_asserter
      @threshold     = threshold
      @max_tools     = max_tools
      @tool_entries  = []

      build_index(tools)
    end

    # Filter tools by TF-IDF similarity to the prompt.
    #
    # @param prompt [String] the user's prompt text
    # @return [Array<String>] tool names above threshold, capped at max_tools
    def filter(prompt)
      filter_with_scores(prompt).map { |entry| entry[:name] }
    end

    # Filter tools and return names with scores for comparison display.
    #
    # @param prompt [String] the user's prompt text
    # @return [Array<Hash{name: String, score: Float}>] sorted by score descending
    def filter_with_scores(prompt)
      return [] if @tool_entries.empty? || prompt.nil? || prompt.strip.empty?

      texts = @tool_entries.map { |e| e[:description] } + [prompt]

      tfidf = Classifier::TFIDF.new
      tfidf.fit(texts)
      vectors = texts.map { |t| tfidf.transform(t) }

      prompt_vector = vectors.last

      scored = @tool_entries.each_with_index.map do |entry, i|
        score = cosine_similarity(prompt_vector, vectors[i])
        { name: entry[:name], score: score }
      end

      scored
        .select { |e| e[:score] >= @threshold }
        .sort_by { |e| -e[:score] }
        .first(@max_tools)
    rescue StandardError => e
      logger.warn("TfidfToolFilter error: #{e.message}")
      []
    end

    private

    def build_index(tools)
      Array(tools).each do |tool|
        name = @fact_asserter.tool_name(tool)
        desc = @fact_asserter.tool_description(tool)
        next if name.empty?

        # Use description if available, otherwise fall back to name
        text = desc.empty? ? name : "#{name} #{desc}"
        @tool_entries << { name: name, description: text }
      end

      @tool_count = @tool_entries.size
    end

    # Cosine similarity between two TF-IDF hash vectors.
    # Same algorithm as SimilarityScorer.cosine_similarity.
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
