# lib/aia/context_manager.rb

module AIA
  # Manages the conversation context for chat sessions.
  class ContextManager
    attr_reader :context, :checkpoints

    # Initializes the ContextManager with an optional system prompt.
    def initialize(system_prompt: nil)
      @context = []
      @checkpoints = {}
      @checkpoint_counter = 0
      add_system_prompt(system_prompt) if system_prompt && !system_prompt.strip.empty?
    end

    # Adds a message to the conversation context.
    #
    # @param role [String] The role of the message sender ('user' or 'assistant').
    # @param content [String] The content of the message.
    def add_to_context(role:, content:)
      @context << { role: role, content: content }
    end

    # Returns the current conversation context.
    # Optionally adds the system prompt if it wasn't added during initialization
    # or needs to be re-added after clearing.
    #
    # @param system_prompt [String, nil] The system prompt to potentially prepend.
    # @return [Array<Hash>] The conversation context array.
    def get_context(system_prompt: nil)
      # Add or replace system prompt if provided and not empty
      if system_prompt && !system_prompt.strip.empty?
        add_system_prompt(system_prompt)
      end
      @context
    end

    # Clears the conversation context, optionally keeping the system prompt.
    #
    # @param keep_system_prompt [Boolean] Whether to retain the initial system prompt.
    def clear_context(keep_system_prompt: true)
      if keep_system_prompt && !@context.empty? && @context.first[:role] == 'system'
        @context = [@context.first]
      else
        @context = []
      end

      # Clear all checkpoints when clearing context
      @checkpoints.clear
      @checkpoint_counter = 0

      # Attempt to clear the LLM client's context as well
      begin
        if AIA.config.client && AIA.config.client.respond_to?(:clear_context)
          AIA.config.client.clear_context
        end

        if AIA.config.respond_to?(:llm) && AIA.config.llm && AIA.config.llm.respond_to?(:clear_context)
          AIA.config.llm.clear_context
        end

        if defined?(RubyLLM) && RubyLLM.respond_to?(:chat) && RubyLLM.chat.respond_to?(:clear_history)
          RubyLLM.chat.clear_history
        end
      rescue => e
        STDERR.puts "ERROR: context_manager clear_context error #{e.message}"
      end
    end

    # Creates a checkpoint of the current context with an optional name.
    #
    # @param name [String, nil] The name of the checkpoint. If nil, uses an incrementing integer.
    # @return [String] The name of the created checkpoint.
    def create_checkpoint(name: nil)
      if name.nil?
        @checkpoint_counter += 1
        name = @checkpoint_counter.to_s
      end

      # Store a deep copy of the current context and its position
      @checkpoints[name] = {
        context: @context.map(&:dup),
        position: @context.size
      }
      @last_checkpoint_name = name
      name
    end

    # Restores the context to a previously saved checkpoint.
    #
    # @param name [String, nil] The name of the checkpoint to restore. If nil, uses the last checkpoint.
    # @return [Boolean] True if restore was successful, false otherwise.
    def restore_checkpoint(name: nil)
      name = @last_checkpoint_name if name.nil?

      return false if name.nil? || !@checkpoints.key?(name)

      # Restore the context from the checkpoint
      checkpoint_data = @checkpoints[name]
      @context = checkpoint_data[:context].map(&:dup)
      true
    end

    # Returns the list of available checkpoint names.
    #
    # @return [Array<String>] The names of all checkpoints.
    def checkpoint_names
      @checkpoints.keys
    end

    # Returns checkpoint information mapped to context positions.
    #
    # @return [Hash<Integer, Array<String>>] Position to checkpoint names mapping.
    def checkpoint_positions
      positions = {}
      @checkpoints.each do |name, data|
        position = data[:position]
        positions[position] ||= []
        positions[position] << name
      end
      positions
    end

    private

    # Adds or replaces the system prompt at the beginning of the context.
    def add_system_prompt(system_prompt)
       # Remove existing system prompt if present
       @context.shift if !@context.empty? && @context.first[:role] == 'system'
       # Add the new system prompt at the beginning
       @context.unshift({ role: 'system', content: system_prompt })
    end
  end
end
