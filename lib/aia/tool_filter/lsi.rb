# frozen_string_literal: true

# lib/aia/tool_filter/lsi.rb
#
# LSI (Latent Semantic Indexing) tool filtering (Option E).
# Uses the `classifier` gem's Classifier::LSI to build a SVD-reduced
# term-document matrix from tool descriptions, then queries per-turn
# using proximity_norms_for_content to rank tools by semantic similarity.
#
# No external model needed — pure Ruby SVD math. Sub-millisecond prep
# and query times.
#
# Supports --load / --save via Marshal serialization.

require 'classifier'

module AIA
  class ToolFilter
    class LSI < ToolFilter
      DEFAULT_MAX_TOOLS = 30
      DEFAULT_SIMILARITY_THRESHOLD = 0.01

      PERSIST_FILENAME = "lsi_tool_filter.marshal"

      # @param tools [Array] tool classes/objects with .name and .description
      # @param fact_asserter [FactAsserter] for extracting tool_name/tool_description
      # @param max_tools [Integer] max tools to return per query (default 30)
      # @param similarity_threshold [Float] minimum similarity to include (default 0.01)
      # @param db_dir [String, nil] directory for persistent storage (e.g. ~/.config/aia)
      # @param load_db [Boolean] load persisted index if available
      # @param save_db [Boolean] persist index to db_dir after building
      def initialize(tools:, fact_asserter:, max_tools: DEFAULT_MAX_TOOLS,
                     similarity_threshold: DEFAULT_SIMILARITY_THRESHOLD,
                     db_dir: nil, load_db: false, save_db: false)
        super(label: "LSI", db_dir: db_dir, load_db: load_db, save_db: save_db)
        @fact_asserter        = fact_asserter
        @max_tools            = max_tools
        @similarity_threshold = similarity_threshold
        @tools                = tools
        @tool_entries         = []   # [{name:, description:}]
        @text_to_name         = {}   # description_text -> tool_name
        @lsi                  = nil
      end

      def persistable?
        true
      end

      protected

      def do_prep
        if @load_db && load_persisted
          $stderr.puts "[LSI] Loaded persisted index from #{persist_path}."
          return
        end

        build_index(@tools)
        save_persisted if @save_db
      end

      def do_filter_with_scores(prompt)
        return [] if @tool_entries.empty? || prompt.nil? || prompt.strip.empty?
        return [] unless @lsi

        norms = @lsi.proximity_norms_for_content(prompt)

        scored = norms.filter_map do |text, score|
          name = @text_to_name[text]
          next unless name
          next if score < @similarity_threshold

          { name: name, score: score.to_f }
        end

        scored
          .sort_by { |e| -e[:score] }
          .first(@max_tools)
      rescue StandardError => e
        $stderr.puts "[LSI] Query error: #{e.message}"
        []
      end

      private

      def persist_path
        File.join(@db_dir, PERSIST_FILENAME)
      end

      # Attempt to load a previously persisted LSI index.
      # Uses direct Marshal.load for minimal deserialization overhead.
      # Returns true on success, false if no persisted data found.
      def load_persisted
        return false unless @db_dir
        return false unless File.exist?(persist_path)

        data = Marshal.load(File.binread(persist_path))
        @lsi          = data[:lsi]
        @tool_entries = data[:tool_entries]
        @tool_count   = @tool_entries.size
        return false if @tool_entries.empty?

        @tool_entries.each { |e| @text_to_name[e[:description]] = e[:name] }
        true
      rescue StandardError => e
        $stderr.puts "[LSI] Failed to load persisted index: #{e.message}"
        @tool_entries = []
        @text_to_name = {}
        @tool_count   = 0
        @lsi          = nil
        false
      end

      # Save the current LSI index to persistent storage.
      # Bundles the LSI object and tool_entries into a single Marshal blob.
      def save_persisted
        return unless @db_dir && @lsi

        FileUtils.mkdir_p(@db_dir)
        data = { lsi: @lsi, tool_entries: @tool_entries }
        File.binwrite(persist_path, Marshal.dump(data))
        $stderr.puts "[LSI] Saved index to #{persist_path}."
      rescue StandardError => e
        $stderr.puts "[LSI] Failed to save index: #{e.message}"
      end

      def build_index(tools)
        @lsi = Classifier::LSI.new

        Array(tools).each do |tool|
          name = @fact_asserter.tool_name(tool)
          desc = @fact_asserter.tool_description(tool)
          next if name.empty?

          text = desc.empty? ? name : "#{name} #{desc}"
          @tool_entries << { name: name, description: text }
          @text_to_name[text] = name

          @lsi.add_item(text, name.to_sym)
        end

        @tool_count = @tool_entries.size
        return if @tool_entries.empty?

        @lsi.build_index
      rescue StandardError => e
        $stderr.puts "[LSI] Index build error: #{e.message}"
        @lsi = nil
      end
    end
  end
end
