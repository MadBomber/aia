# frozen_string_literal: true

# lib/aia/tool_filter/embedding_model_loader.rb
#
# Shared mixin for ToolFilter subclasses that use the Informers embedding
# pipeline. Centralises the load + log sequence used by Zvec and SqliteVec.

module AIA
  class ToolFilter
    module EmbeddingModelLoader
      # Load the Informers embedding pipeline and assign it to @model.
      # Logs progress to $stderr using the caller's label.
      #
      # @param label [String] filter label for log messages (e.g. "SqVec")
      # @param model_name [String] HuggingFace model identifier
      def load_embedding_model(label, model_name)
        $stderr.puts "[#{label}] Loading embedding model (#{model_name})..."
        @model = Informers.pipeline("embedding", model_name)
        $stderr.puts "[#{label}] Embedding model loaded."
      end
    end
  end
end
