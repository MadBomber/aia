# lib/aia/topic_context.rb
# Just thinking about the problem ...
# maybe a directive like //topic [topic]
# sets manually (when present) or dynamically when not present
# and //topics - will list current topics
# thinking about the //checkpoint and //restore directives
#
module AIA
  class TopicContext
    attr_reader :context_size

    # Initialize topic context manager
    # @param context_size [Integer] max allowed bytes per topic
    def initialize(context_size = 128_000)
      @storage = Hash.new { |h, k| h[k] = [] } # auto-initialize empty array
      @context_size = context_size
      @total_chars = 0
      @mutex = Mutex.new # ensure thread safety
    end

    # Store a request/response pair under the given topic (or auto-generate one)
    # @param request [String]
    # @param response [String]
    # @param topic [String, nil]
    # @return [String] topic name used
    def store_conversation(request, response, topic = nil)
      raise ArgumentError, "request and response must be strings" unless request.is_a?(String) && response.is_a?(String)

      topic ||= generate_topic(request)
      size = request.bytesize + response.bytesize

      @mutex.synchronize do
        # Add the new context
        @storage[topic] << { request:, response:, size:, time: Time.now }

        # Update the global total
        @total_chars += size

        # Trim old entries if we exceeded the per-topic limit
        trim_topic(topic)
      end

      topic
    end

    # Return an array of contexts for the given topic
    # @param topic [String]
    # @return [Array<Hash>]
    def get_conversation(topic)
      @mutex.synchronize { @storage[topic] || [] }
    end

    # All topic names
    # @return [Array<String>]
    def topics
      @mutex.synchronize { @storage.keys }
    end

    # Hash of topic => array_of_contexts
    # @return [Hash<String, Array<Hash>>]
    def all_conversations
      @mutex.synchronize { @storage.dup }
    end

    # Total number of characters stored across all topics
    # @return [Integer]
    def total_chars
      @mutex.synchronize { @total_chars }
    end

    # Empty the storage and reset counters
    def clear
      @mutex.synchronize do
        @storage.clear
        @total_chars = 0
      end
    end

    # Get memory usage statistics for a topic
    # @param topic [String]
    # @return [Hash{Symbol => Integer}]
    def topic_stats(topic)
      @mutex.synchronize do
        return {} unless @storage.key?(topic)

        {
          count: @storage[topic].length,
          size: topic_total_size(topic),
          avg_size: topic_total_size(topic).fdiv(@storage[topic].length),
        }
      end
    end

    private

    # Topic extractor with better heuristic - uses first meaningful 3 words
    # @param request [String]
    # @return [String]
    def generate_topic(request)
      cleaned = request.downcase.gsub(/[^a-z0-9\s]/, "")
      words = cleaned.split
      return "general" if words.empty?

      words.first(3).join("_")
    end

    # Remove oldest contexts from the topic until size <= @context_size
    # @param topic [String]
    def trim_topic(topic)
      return unless @storage.key?(topic) && @storage[topic].size > 1

      while topic_total_size(topic) > @context_size
        removed = @storage[topic].shift # oldest context
        @total_chars -= removed[:size]  # adjust global counter
      end
    end

    # Helper to compute the sum of sizes for a topic
    # @param topic [String]
    # @return [Integer]
    def topic_total_size(topic)
      @storage[topic].sum { |ctx| ctx[:size] }
    end
  end
end
