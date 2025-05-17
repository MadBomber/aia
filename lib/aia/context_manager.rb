# lib/aia/context_manager.rb

module AIA
  # Manages the conversation context for chat sessions.
  class ContextManager
    attr_reader :context

    # Initializes the ContextManager with an optional system prompt.
    def initialize(system_prompt: nil)
      @context = []
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
      # Ensure system prompt is present if provided and not already the first message
      if system_prompt && !system_prompt.strip.empty? && (@context.empty? || @context.first[:role] != 'system')
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
        AIA.debug_me(tag: '== context_manager clear_context error =='){[ :e, e.message, e.backtrace ]}
      end
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
