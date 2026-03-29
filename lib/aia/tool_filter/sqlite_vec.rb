# frozen_string_literal: true

# lib/aia/tool_filter/sqlite_vec.rb
#
# SQLite-vec based semantic vector search tool filtering (Option D).
# Uses the `informers` gem to generate 384-dim embeddings with
# sentence-transformers/all-MiniLM-L6-v2 (same model as Zvec), stores
# them in a SQLite database via the `sqlite-vec` extension, then queries
# per-turn by embedding the user prompt and finding nearest tool vectors
# via KNN cosine distance.
#
# Supports --load / --save for database persistence:
#   --save: writes database to <db_dir>/sqlite_vec_tool_filter.db
#   --load: reopens persisted database, skipping embedding generation

require 'sqlite3'
require 'sqlite_vec'
require 'informers'
require_relative 'embedding_model_loader'

module AIA
  class ToolFilter
    class SqliteVec < ToolFilter
      include EmbeddingModelLoader
      EMBEDDING_DIM   = 384
      MODEL_NAME      = "sentence-transformers/all-MiniLM-L6-v2"
      DEFAULT_TOP_K   = 30
      # sqlite-vec returns L2 distance by default.  With distance_metric=cosine
      # (vec0 option), distance 0 = identical, 2 = opposite.
      # We convert: similarity = 1.0 - (distance / 2.0), clamped to [0,1].
      DEFAULT_SIMILARITY_THRESHOLD = 0.20

      PERSIST_FILENAME = "sqlite_vec_tool_filter.db"

      # @param tools [Array] tool classes/objects with .name and .description
      # @param fact_asserter [FactAsserter] for extracting tool_name/tool_description
      # @param top_k [Integer] max tools to return per query (default 30)
      # @param similarity_threshold [Float] minimum cosine similarity to include (default 0.20)
      # @param db_dir [String, nil] directory for persistent storage (e.g. ~/.config/aia)
      # @param load_db [Boolean] load persisted database if available
      # @param save_db [Boolean] persist database to db_dir after building
      def initialize(tools:, fact_asserter:, top_k: DEFAULT_TOP_K,
                     similarity_threshold: DEFAULT_SIMILARITY_THRESHOLD,
                     db_dir: nil, load_db: false, save_db: false)
        super(label: "SqVec", db_dir: db_dir, load_db: load_db, save_db: save_db)
        @fact_asserter        = fact_asserter
        @top_k                = top_k
        @similarity_threshold = similarity_threshold
        @tools                = tools
        @tool_entries         = []
        @tool_index           = {}
        @db                   = nil
        @model                = nil
      end

      def persistable?
        true
      end

      # Close the database handle.
      def cleanup
        @db&.close
        @db = nil
      rescue StandardError
        # best-effort cleanup
      end

      protected

      def do_prep
        current_fp = fingerprint_from_tools(@tools)

        if @load_db && load_persisted(expected_fingerprint: current_fp)
          $stderr.puts "[SqVec] Loaded persisted database from #{persist_path}."
          return
        end

        build_index(@tools, fingerprint: current_fp)
      end

      def do_filter_with_scores(prompt)
        return [] if @tool_entries.empty? || prompt.nil? || prompt.strip.empty?
        return [] unless @db && @model

        query_vec = @model.(prompt)
        query_blob = query_vec.pack("f*")

        rows = @db.execute(<<~SQL, [query_blob, @top_k])
          SELECT rowid, distance
          FROM vec_tools
          WHERE embedding MATCH ?
          ORDER BY distance
          LIMIT ?
        SQL

        scored = rows.map do |rowid, distance|
          entry = @tool_index[rowid.to_i]
          next unless entry

          similarity = (1.0 - (distance / 2.0)).clamp(0.0, 1.0)
          { name: entry[:name], score: similarity }
        end.compact

        scored
          .select { |e| e[:score] >= @similarity_threshold }
          .sort_by { |e| -e[:score] }
      rescue StandardError => e
        $stderr.puts "[SqVec] Query error: #{e.message}"
        []
      end

      private

      # Path for the persisted database file.
      def persist_path
        File.join(@db_dir, PERSIST_FILENAME)
      end

      # Attempt to load a previously persisted database.
      # Returns true on success, false if no persisted data found or fingerprint mismatch.
      def load_persisted(expected_fingerprint: nil)
        return false unless @db_dir

        db_path = persist_path
        return false unless File.exist?(db_path)

        @db = SQLite3::Database.new(db_path)
        @db.enable_load_extension(true)
        ::SqliteVec.load(@db)
        @db.enable_load_extension(false)

        # Check fingerprint if aia_config table exists
        if expected_fingerprint
          config_table_exists = @db.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='aia_config'"
          ).any?

          if config_table_exists
            rows = @db.execute("SELECT value FROM aia_config WHERE key='fingerprint'")
            saved_fp = rows.first&.first
            if saved_fp && expected_fingerprint != saved_fp
              $stderr.puts "[SqVec] Tool set changed since last save. Rebuilding index."
              @db.close
              @db = nil
              return false
            end
          end
        end

        # Restore tool_entries and tool_index from the tool_meta table
        rows = @db.execute("SELECT rowid, name, description FROM tool_meta ORDER BY rowid")
        @tool_index   = {}
        @tool_entries = rows.map do |rowid, name, desc|
          entry = { name: name, description: desc }
          @tool_index[rowid.to_i] = entry
          entry
        end
        @tool_count = @tool_entries.size
        return false if @tool_entries.empty?

        load_embedding_model(@label, MODEL_NAME)

        true
      rescue StandardError => e
        $stderr.puts "[SqVec] Failed to load persisted database: #{e.message}"
        @tool_entries = []
        @tool_count   = 0
        @db&.close
        @db = nil
        false
      end

      def build_index(tools, fingerprint: nil)
        Array(tools).each do |tool|
          name = @fact_asserter.tool_name(tool)
          desc = @fact_asserter.tool_description(tool)
          next if name.empty?

          text = desc.empty? ? name : "#{name} #{desc}"
          @tool_entries << { name: name, description: text }
        end

        @tool_count = @tool_entries.size
        return if @tool_entries.empty?

        load_embedding_model(@label, MODEL_NAME)

        $stderr.puts "[SqVec] Generating embeddings for #{@tool_entries.size} tools..."
        embeddings = @tool_entries.map { |entry| @model.(entry[:description]) }
        $stderr.puts "[SqVec] Embeddings generated (#{EMBEDDING_DIM} dimensions each)."

        create_database(embeddings, fingerprint: fingerprint)
      end

      def create_database(embeddings, fingerprint: nil)
        # Use file path when saving, in-memory otherwise
        db_path = (@save_db && @db_dir) ? persist_path : ":memory:"

        if db_path != ":memory:"
          FileUtils.mkdir_p(File.dirname(db_path))
          File.delete(db_path) if File.exist?(db_path)
        end

        @db = SQLite3::Database.new(db_path)
        @db.enable_load_extension(true)
        ::SqliteVec.load(@db)
        @db.enable_load_extension(false)

        @db.execute(<<~SQL)
          CREATE VIRTUAL TABLE vec_tools USING vec0(
            embedding float[#{EMBEDDING_DIM}] distance_metric=cosine
          )
        SQL

        # Store tool name/description for persistence
        @db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS tool_meta (
            rowid INTEGER PRIMARY KEY,
            name  TEXT NOT NULL,
            description TEXT NOT NULL
          )
        SQL

        # Store configuration metadata (e.g. fingerprint) for staleness detection
        @db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS aia_config (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        SQL

        @tool_index = {}
        @db.transaction do
          @tool_entries.each_with_index do |entry, i|
            blob = embeddings[i].pack("f*")
            rid  = i + 1
            @tool_index[rid] = entry
            @db.execute(
              "INSERT INTO vec_tools(rowid, embedding) VALUES (?, ?)",
              [rid, blob]
            )
            @db.execute(
              "INSERT INTO tool_meta(rowid, name, description) VALUES (?, ?, ?)",
              [rid, entry[:name], entry[:description]]
            )
          end

          if fingerprint
            @db.execute(
              "INSERT OR REPLACE INTO aia_config(key, value) VALUES ('fingerprint', ?)",
              [fingerprint]
            )
          end
        end

        location = db_path == ":memory:" ? "in-memory" : db_path
        $stderr.puts "[SqVec] Indexed #{@tool_entries.size} tools into sqlite-vec (#{location})."
      rescue StandardError => e
        $stderr.puts "[SqVec] Database creation error: #{e.message}"
        @db&.close
        @db = nil
      end
    end
  end
end
