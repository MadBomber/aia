# lib/aia/variable_input_collector.rb

require 'json'
require 'fileutils'

module AIA
  class VariableInputCollector
    def initialize
      # No prompt dependency — just handles user input for parameter collection
    end

    # :reek:TooManyStatements -- one Reline round-trip: question build, readline, Ctrl+D/empty fallbacks, prompt_proc restore
    def request_variable_value(variable_name:, default_value: nil)
      return default_or_required(variable_name, default_value) unless terminal?

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

        return default_or_required(variable_name, default_value) if input.nil? # Ctrl+D

        value = input.strip
        return default_or_required(variable_name, default_value) if value.empty?

        value
      rescue Interrupt
        raise AIA::Error, "Variable input interrupted."
      ensure
        Reline.line_editor.prompt_proc = original_prompt_proc
      end
    end

    private

    # No terminal to ask (piped stdin with no /dev/tty): fall back to defaults.
    def terminal?
      $stdin.tty?
    end

    def default_or_required(variable_name, default_value)
      return default_value if default_value
      raise AIA::Error, "Parameter '#{variable_name}' is required."
    end
  end
end
