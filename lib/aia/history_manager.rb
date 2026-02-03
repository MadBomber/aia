# lib/aia/history_manager.rb

require 'json'
require 'fileutils'

module AIA
  class HistoryManager
    def initialize
      # No prompt dependency — just handles user input for parameter collection
    end


    def request_variable_value(variable_name:, default_value: nil)
      Reline::HISTORY.clear

      question = if default_value.nil?
                   "Value for #{variable_name} (required): "
                 else
                   "Value for #{variable_name} (#{default_value}): "
                 end

      Reline.output = $stdout

      original_prompt_proc = Reline.line_editor.prompt_proc

      begin
        input = Reline.readline(question, true)

        if input.nil? # Ctrl+D
          return default_value if default_value
          puts "\nParameter '#{variable_name}' is required."
          exit(1)
        end

        value = input.strip
        if value.empty?
          return default_value if default_value
          puts "Parameter '#{variable_name}' is required."
          exit(1)
        end

        value
      rescue Interrupt
        puts "\nVariable input interrupted."
        exit(1)
      ensure
        Reline.line_editor.prompt_proc = original_prompt_proc
      end
    end
  end
end
