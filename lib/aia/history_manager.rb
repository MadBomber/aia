# lib/aia/history_manager.rb




require 'json'
require 'fileutils'

module AIA

  class HistoryManager
    MAX_VARIABLE_HISTORY = 5


    def initialize
      @history = []
      @variable_history_file = File.join(ENV['HOME'], '.aia', 'variable_history.json')
      ensure_history_file_exists
    end


    def history
      @history
    end


    def history=(new_history)
      @history = new_history
    end



    def add_to_history(role, content)
      @history << { role: role, content: content }
    end


    def clear_history
      @history = []
    end



    def build_conversation_context(current_prompt, system_prompt_id = nil)
      system_prompt = ""
      if system_prompt_id
        system_prompt = PromptManager::Prompt.get(id: system_prompt_id, external_binding: binding).to_s rescue ""
      end

      history_text = ""
      if !@history.empty?
        @history.each do |entry|
          history_text += "#{entry[:role].capitalize}: #{entry[:content]}\n\n"
        end
      end

      if !system_prompt.empty?
        "#{system_prompt}\n\n#{history_text}User: #{current_prompt}"
      else
        "#{history_text}User: #{current_prompt}"
      end
    end


    def setup_variable_history(history_values)
      Reline::HISTORY.clear
      history_values.each do |value|
        Reline::HISTORY.push(value) unless value.nil? || value.empty?
      end
    end


    def load_variable_history
      begin
        JSON.parse(File.read(@variable_history_file))
      rescue JSON::ParserError
        {} # Return empty hash if file is invalid
      end
    end



    def save_variable_history(history)
      File.write(@variable_history_file, JSON.pretty_generate(history))
    end



    def get_variable_history(prompt_id, variable, value = nil)
      history = load_variable_history
      prompt_history = history[prompt_id] || {}
      var_history = prompt_history[variable] || []

      if value && !value.empty?
        var_history.delete(value)

        var_history << value

        var_history.shift if var_history.size > MAX_VARIABLE_HISTORY

        prompt_history[variable] = var_history
        history[prompt_id] = prompt_history

        save_variable_history(history)
      end

      var_history
    end

    private


    def ensure_history_file_exists
      dir = File.dirname(@variable_history_file)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

      unless File.exist?(@variable_history_file)
        File.write(@variable_history_file, '{}')
      end
    end
  end
end
