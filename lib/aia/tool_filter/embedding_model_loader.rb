# frozen_string_literal: true

# lib/aia/tool_filter/embedding_model_loader.rb
#
# Shared mixin for ToolFilter subclasses that use the Informers embedding
# pipeline. Maintains a module-level cache so that when multiple filters
# are active simultaneously (e.g. -B and -C) the heavyweight model is
# loaded only once and shared between them.

module AIA
  class ToolFilter
    module EmbeddingModelLoader
      # Module-level cache: model_name (String) => loaded pipeline object.
      # Protected by a Mutex for safe use during concurrent filter prep.
      @_model_cache = {}
      @_mutex = Mutex.new

      # Expose cache for testing (clear between tests).
      def self._cache
        @_model_cache
      end

      def self._mutex
        @_mutex
      end

      # Load (or reuse) the Informers embedding pipeline, assigning it to
      # @model on the including object.
      #
      # @param label [String] filter label for log messages (e.g. "SqVec")
      # @param model_name [String] HuggingFace model identifier
      def load_embedding_model(label, model_name)
        cached = EmbeddingModelLoader._mutex.synchronize do
          EmbeddingModelLoader._cache[model_name]
        end

        if cached
          @model = cached
          $stderr.puts "[#{label}] Using cached embedding model (#{model_name})."
          return
        end

        $stderr.puts "[#{label}] Loading embedding model (#{model_name})..."
        new_model = Informers.pipeline("embedding", model_name)

        EmbeddingModelLoader._mutex.synchronize do
          # Double-checked: another thread may have loaded it while we waited
          EmbeddingModelLoader._cache[model_name] ||= new_model
          @model = EmbeddingModelLoader._cache[model_name]
        end

        $stderr.puts "[#{label}] Embedding model loaded."
      end
    end
  end
end
