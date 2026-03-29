# frozen_string_literal: true

# lib/aia/tool_filter/tfidf.rb
#
# TF-IDF based tool filtering (Option A).
# Built once at session start from all tool descriptions (local + MCP).
# Per-turn: scores user prompt against each tool's description via cosine
# similarity and returns tool names above threshold, capped at max_tools.
#
# Text is normalized before indexing and querying:
#   - Lowercased and tokenized on word boundaries
#   - Each token is Porter-stemmed (via fast-stemmer, a classifier dependency)
#   - Parameter names are appended to each tool's description text

require 'classifier'
require 'fast-stemmer'

module AIA
  class ToolFilter
    class TFIDF < ToolFilter
      DEFAULT_THRESHOLD = 0.05
      DEFAULT_MAX_TOOLS = 30

      # @param tools [Array] tool classes/objects with .name and .description
      # @param fact_asserter [FactAsserter] used for tool_name/tool_description extraction
      # @param threshold [Float] minimum cosine similarity to include a tool (default 0.05)
      # @param max_tools [Integer] maximum tools to return per turn (default 30)
      def initialize(tools:, fact_asserter:, threshold: DEFAULT_THRESHOLD, max_tools: DEFAULT_MAX_TOOLS)
        super(label: "TF-IDF")
        @fact_asserter = fact_asserter
        @threshold     = threshold
        @max_tools     = max_tools
        @tools         = tools
        @tool_entries  = []
        @tfidf         = nil
        @tool_vectors  = []
      end

      protected

      def do_prep
        build_index(@tools)
        return if @tool_entries.empty?

        tool_texts = @tool_entries.map { |e| e[:description] }
        @tfidf = Classifier::TFIDF.new
        @tfidf.fit(tool_texts)
        @tool_vectors = tool_texts.map { |t| @tfidf.transform(t) }
      end

      def do_filter_with_scores(prompt)
        return [] if @tool_entries.empty? || @tfidf.nil? || prompt.nil? || prompt.strip.empty?

        query_vector = @tfidf.transform(normalize(prompt))

        scored = @tool_entries.each_with_index.map do |entry, i|
          score = cosine_similarity(query_vector, @tool_vectors[i])
          { name: entry[:name], score: score }
        end

        scored
          .select { |e| e[:score] >= @threshold }
          .sort_by { |e| -e[:score] }
          .first(@max_tools)
      rescue StandardError => e
        warn "ToolFilter::TFIDF error: #{e.message}"
        []
      end

      private

      def build_index(tools)
        Array(tools).each do |tool|
          name   = @fact_asserter.tool_name(tool)
          desc   = @fact_asserter.tool_description(tool)
          params = extract_param_names(tool)
          next if name.empty?

          raw_text = [name, desc, params].reject(&:empty?).join(" ")
          expanded = AIA::ToolFilter::WordNetExpander.expand(raw_text)
          @tool_entries << { name: name, description: normalize(expanded) }
        end

        @tool_count = @tool_entries.size
      end

      # Collect parameter names from a tool object.
      # RubyLLM::Tool exposes .parameters as {sym => Parameter}.
      # Parameter names are discriminative (e.g. "sql_query", "xpath", "url").
      def extract_param_names(tool)
        return "" unless tool.respond_to?(:parameters)

        params = tool.parameters
        return "" unless params.respond_to?(:values)

        names = params.values.map do |p|
          p.respond_to?(:name) ? p.name.to_s : p.to_s
        end
        names.reject(&:empty?).join(" ")
      rescue StandardError
        ""
      end

      # Normalize text for TF-IDF: tokenize, stem each word, rejoin.
      # Applied symmetrically to both tool text (at index time) and
      # the user prompt (at query time) so the vocabulary matches.
      def normalize(text)
        text.downcase
            .scan(/[a-z]+/)
            .map(&:stem)
            .join(" ")
      end

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
end
