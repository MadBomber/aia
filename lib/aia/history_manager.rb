# lib/aia/history_manager.rb

require 'json'
require 'fileutils'

module AIA
  class HistoryManager
    MAX_VARIABLE_HISTORY = 5

    # prompt is PromptManager::Prompt instance
    def initialize(prompt:)
      @prompt  = prompt
      @history = []
    end


    def history
      @history
    end


    def history=(new_history)
      @history = new_history
    end


    def setup_variable_history(history_values)
      Reline::HISTORY.clear
      history_values.each do |value|
        Reline::HISTORY.push(value) unless value.nil? || value.empty?
      end
    end


    def get_variable_history(variable, value = '')
      return if value.nil? || value.empty?

      values = @prompt.parameters[variable]
      if values.include?(value)
        values.delete(value)
      end

      values << value

      if values.size > MAX_VARIABLE_HISTORY
        values.shift
      end

      @prompt.parameters[variable] = values
    end


    def request_variable_value(variable_name:, history_values: [])
      setup_variable_history(history_values) # Setup Reline's history for completion

      default_value = history_values.last || ''
      question = "Value for #{variable_name} (#{default_value}): "

      # Ensure Reline is writing to stdout explicitly for this interaction
      Reline.output = $stdout

      # Store the original prompt proc to restore later
      original_prompt_proc = Reline.line_editor.prompt_proc

      # Note: Temporarily setting prompt_proc might not be needed if passing prompt to readline works.
      # Reline.line_editor.prompt_proc = ->(context) { [question] }

      begin
        input = Reline.readline(question, true)
        return default_value if input.nil? # Handle Ctrl+D -> use default

        chosen_value = input.strip.empty? ? default_value : input.strip
        # Update the persistent history for this variable
        get_variable_history(variable_name, chosen_value)
        return chosen_value
      rescue Interrupt
        puts "\nVariable input interrupted."
        exit(1) # Exit cleanly on Ctrl+C
      ensure
        # Restore the original prompt proc
        Reline.line_editor.prompt_proc = original_prompt_proc
      end
    end
  end
end
