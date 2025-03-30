# lib/aia/history_manager.rb
#
# This file contains the HistoryManager class for handling conversation and variable history.
# The HistoryManager class is responsible for managing conversation history and
# variable history persistence. It handles loading, saving, and manipulating
# history data throughout a session.

require 'json'
require 'fileutils'

module AIA
  # The HistoryManager class is responsible for managing conversation history and
  # variable history persistence. It handles loading, saving, and manipulating
  # history data throughout a session.
  class HistoryManager
    # Maximum number of history entries per keyword
    MAX_VARIABLE_HISTORY = 5

    # Initializes a new HistoryManager with the given configuration.
    #
    # @param config [OpenStruct] the configuration object containing settings
    def initialize(config)
      @config = config
      @history = []
      @variable_history_file = File.join(ENV['HOME'], '.aia', 'variable_history.json')
      ensure_history_file_exists
    end

    # Returns the current conversation history.
    #
    # @return [Array<Hash>] the conversation history
    def history
      @history
    end

    # Sets the conversation history.
    #
    # @param new_history [Array<Hash>] the new conversation history
    def history=(new_history)
      @history = new_history
    end

    # Adds an entry to the conversation history.
    #
    # @param role [String] the role of the entry (e.g., 'user', 'assistant')
    # @param content [String] the content of the entry
    def add_to_history(role, content)
      @history << { role: role, content: content }
    end

    # Clears the conversation history.
    def clear_history
      @history = []
    end

    # Builds the conversation context by combining the system prompt, chat
    # history, and the current user prompt.
    #
    # @param current_prompt [String] the current user prompt
    # @param system_prompt_id [String, nil] optional system prompt ID
    # @return [String] the complete conversation context
    def build_conversation_context(current_prompt, system_prompt_id = nil)
      # Use the system prompt if available
      system_prompt = ""
      if system_prompt_id
        system_prompt = PromptManager::Prompt.get(id: system_prompt_id).to_s rescue ""
      end

      # Prepare the conversation history
      history_text = ""
      if !@history.empty?
        @history.each do |entry|
          history_text += "#{entry[:role].capitalize}: #{entry[:content]}\n\n"
        end
      end

      # Combine system prompt, history, and current prompt
      if !system_prompt.empty?
        "#{system_prompt}\n\n#{history_text}User: #{current_prompt}"
      else
        "#{history_text}User: #{current_prompt}"
      end
    end

    # Sets up Reline history with the provided variable history values.
    #
    # @param history_values [Array<String>] the history values to set up
    def setup_variable_history(history_values)
      Reline::HISTORY.clear
      history_values.each do |value|
        Reline::HISTORY.push(value) unless value.nil? || value.empty?
      end
    end

    # Loads the variable history from a JSON file.
    #
    # @return [Hash] the loaded variable history
    def load_variable_history
      begin
        JSON.parse(File.read(@variable_history_file))
      rescue JSON::ParserError
        {} # Return empty hash if file is invalid
      end
    end

    # Saves the variable history to a JSON file.
    #
    # @param history [Hash] the variable history to save
    def save_variable_history(history)
      File.write(@variable_history_file, JSON.pretty_generate(history))
    end

    # Gets variable history for a prompt and variable, managing additions.
    #
    # @param prompt_id [String] the prompt ID
    # @param variable [String] the variable name
    # @param value [String, nil] optional new value to add to history
    # @return [Array<String>] the variable history
    def get_variable_history(prompt_id, variable, value = nil)
      history = load_variable_history
      prompt_history = history[prompt_id] || {}
      var_history = prompt_history[variable] || []
      
      # Add new value if provided
      if value && !value.empty?
        # Remove value if it's already in history to avoid duplicates
        var_history.delete(value)
        
        # Add to end of history (most recent)
        var_history << value
        
        # Trim history to max size
        var_history.shift if var_history.size > MAX_VARIABLE_HISTORY
        
        # Update history in memory
        prompt_history[variable] = var_history
        history[prompt_id] = prompt_history
        
        # Save updated history
        save_variable_history(history)
      end
      
      var_history
    end

    private

    # Ensures that the history file directory exists and creates an empty
    # history file if it does not exist.
    def ensure_history_file_exists
      dir = File.dirname(@variable_history_file)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

      # Create empty history file if it doesn't exist
      unless File.exist?(@variable_history_file)
        File.write(@variable_history_file, '{}')
      end
    end
  end
end
