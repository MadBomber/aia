# lib/aia/input_collector.rb
# frozen_string_literal: true

module AIA
  class InputCollector
    # Collect variable values from user input via VariableInputCollector
    def collect(parameters)
      return {} if parameters.nil? || parameters.empty?

      values = {}
      input_manager = AIA::VariableInputCollector.new

      parameters.each do |name, default|
        value = input_manager.request_variable_value(
          variable_name: name,
          default_value: default,
        )
        values[name] = value
      end

      values
    end
  end
end
