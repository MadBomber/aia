# frozen_string_literal: true

# lib/aia/tool_filter/zvec.rb
#
# Zvec-based semantic vector search tool filtering (Option C).
# Uses the `informers` gem to generate 384-dim embeddings with
# sentence-transformers/all-MiniLM-L6-v2, stores them in a zvec
# HNSW collection, then queries per-turn by embedding the user prompt
# and finding nearest tool vectors via cosine similarity.
#
# Supports --load / --save for database persistence:
#   --save: writes collection to <db_dir>/zvec_tool_filter/
#   --load: reopens persisted collection, skipping embedding generation

require 'zvec'
require 'informers'
require 'tmpdir'
require 'fileutils'
require 'json'

module AIA
  class ToolFilter
    class Zvec < ToolFilter
      EMBEDDING_DIM   = 384
      MODEL_NAME      = "sentence-transformers/all-MiniLM-L6-v2"
      DEFAULT_TOP_K   = 30
      # Zvec COSINE metric returns distance (0 = identical).
      # Similarity = 1.0 - distance.  We keep tools with similarity >= threshold.
      DEFAULT_SIMILARITY_THRESHOLD = 0.20

      PERSIST_SUBDIR  = "zvec_tool_filter"
      META_FILENAME   = "tool_entries.json"

      # @param tools [Array] tool classes/objects with .name and .description
      # @param fact_asserter [FactAsserter] for extracting tool_name/tool_description
      # @param top_k [Integer] max tools to return per query (default 30)
      # @param similarity_threshold [Float] minimum cosine similarity to include (default 0.20)
      # @param db_dir [String, nil] directory for persistent storage (e.g. ~/.config/aia)
      # @param load_db [Boolean] load persisted collection if available
      # @param save_db [Boolean] persist collection to db_dir after building
      def initialize(tools:, fact_asserter:, top_k: DEFAULT_TOP_K,
                     similarity_threshold: DEFAULT_SIMILARITY_THRESHOLD,
                     db_dir: nil, load_db: false, save_db: false)
        super(label: "Zvec", db_dir: db_dir, load_db: load_db, save_db: save_db)
        @fact_asserter        = fact_asserter
        @top_k                = top_k
        @similarity_threshold = similarity_threshold
        @tools                = tools
        @tool_entries         = []
        @collection           = nil
        @model                = nil
        @tmpdir               = nil
      end

      def persistable?
        true
      end

      # Clean up the temporary collection directory.
      # Persistent directories (--save) are intentionally kept.
      def cleanup
        FileUtils.rm_rf(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
      rescue StandardError
        # best-effort cleanup
      end

      protected

      def do_prep
        if @load_db && load_persisted
          $stderr.puts "[Zvec] Loaded persisted collection from #{persist_dir}."
          return
        end

        build_index(@tools)
        save_persisted if @save_db
      end

      def do_filter_with_scores(prompt)
        return [] if @tool_entries.empty? || prompt.nil? || prompt.strip.empty?
        return [] unless @collection && @model

        query_vec = @model.(prompt)
        results = @collection.query_vector("embedding", query_vec, top_k: @top_k)
        schema = @collection.schema

        scored = results.map do |doc|
          h = doc.to_h(schema)
          similarity = (1.0 - (h['score'] || 0.0)).clamp(0.0, 1.0)
          { name: h['tool_name'], score: similarity }
        end

        scored
          .select { |e| e[:score] >= @similarity_threshold }
          .sort_by { |e| -e[:score] }
      rescue StandardError => e
        $stderr.puts "[Zvec] Query error: #{e.message}"
        []
      end

      private

      # Directory for persistent storage.
      def persist_dir
        File.join(@db_dir, PERSIST_SUBDIR)
      end

      def collection_path
        File.join(persist_dir, "collection")
      end

      def meta_path
        File.join(persist_dir, META_FILENAME)
      end

      # Attempt to load a previously persisted collection.
      # Returns true on success, false if no persisted data found.
      def load_persisted
        return false unless @db_dir
        return false unless File.exist?(meta_path) && Dir.exist?(collection_path)

        @tool_entries = JSON.parse(File.read(meta_path), symbolize_names: true)
        @tool_count   = @tool_entries.size
        return false if @tool_entries.empty?

        $stderr.puts "[Zvec] Loading embedding model (#{MODEL_NAME})..."
        @model = Informers.pipeline("embedding", MODEL_NAME)
        $stderr.puts "[Zvec] Embedding model loaded."

        @collection = ::Zvec::Collection.open(collection_path)
        true
      rescue StandardError => e
        $stderr.puts "[Zvec] Failed to load persisted collection: #{e.message}"
        @tool_entries = []
        @tool_count   = 0
        @collection   = nil
        false
      end

      # Save the current collection to persistent storage.
      def save_persisted
        return unless @db_dir && @collection

        FileUtils.mkdir_p(persist_dir)

        # Copy tmpdir contents to persistent location
        if @tmpdir
          target = collection_path
          FileUtils.rm_rf(target) if Dir.exist?(target)
          FileUtils.cp_r(File.join(@tmpdir, "tools"), target)
        end

        File.write(meta_path, JSON.pretty_generate(@tool_entries))
        $stderr.puts "[Zvec] Saved collection to #{persist_dir}."
      rescue StandardError => e
        $stderr.puts "[Zvec] Failed to save collection: #{e.message}"
      end

      def build_index(tools)
        Array(tools).each do |tool|
          name = @fact_asserter.tool_name(tool)
          desc = @fact_asserter.tool_description(tool)
          next if name.empty?

          text = desc.empty? ? name : "#{name} #{desc}"
          @tool_entries << { name: name, description: text }
        end

        @tool_count = @tool_entries.size
        return if @tool_entries.empty?

        $stderr.puts "[Zvec] Loading embedding model (#{MODEL_NAME})..."
        @model = Informers.pipeline("embedding", MODEL_NAME)
        $stderr.puts "[Zvec] Embedding model loaded."

        $stderr.puts "[Zvec] Generating embeddings for #{@tool_entries.size} tools..."
        embeddings = @tool_entries.map { |entry| @model.(entry[:description]) }
        $stderr.puts "[Zvec] Embeddings generated (#{EMBEDDING_DIM} dimensions each)."

        create_collection(embeddings)
      end

      def create_collection(embeddings)
        @tmpdir = Dir.mktmpdir("aia_zvec_tools")

        pk_field        = ::Zvec::FieldSchema.create("pk", ::Zvec::DataType::STRING)
        tool_name_field = ::Zvec::FieldSchema.create("tool_name", ::Zvec::DataType::STRING)
        embedding_field = ::Zvec::FieldSchema.create("embedding", ::Zvec::DataType::VECTOR_FP32,
                            dimension:    EMBEDDING_DIM,
                            index_params: ::Zvec::HnswIndexParams.new(::Zvec::MetricType::COSINE))

        schema = ::Zvec::CollectionSchema.create("aia_tools",
                   [pk_field, tool_name_field, embedding_field])

        col_path = File.join(@tmpdir, "tools")
        @collection = ::Zvec::Collection.create_and_open(col_path, schema)

        zvec_docs = @tool_entries.each_with_index.map do |entry, i|
          doc = ::Zvec::Doc.new
          pk = "tool#{i}"
          doc.pk = pk
          doc.set_field("pk",         ::Zvec::DataType::STRING,      pk)
          doc.set_field("tool_name",  ::Zvec::DataType::STRING,      entry[:name])
          doc.set_field("embedding",  ::Zvec::DataType::VECTOR_FP32, embeddings[i])
          doc
        end

        statuses = @collection.insert(zvec_docs)
        @collection.flush

        ok_count = statuses.count { |s| s == "OK" }
        $stderr.puts "[Zvec] Indexed #{ok_count}/#{zvec_docs.size} tools into vector collection."
      rescue StandardError => e
        $stderr.puts "[Zvec] Collection creation error: #{e.message}"
        @collection = nil
      end
    end
  end
end
