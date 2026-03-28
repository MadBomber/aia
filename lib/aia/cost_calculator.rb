# frozen_string_literal: true

# lib/aia/cost_calculator.rb
#
# Shared cost calculation logic used by SessionTracker and UIPresenter.
# Looks up per-million token pricing from RubyLLM::Models and returns
# a breakdown hash.

module AIA
  module CostCalculator
    # @param model_id [String, nil]
    # @param input_tokens [Integer]
    # @param output_tokens [Integer]
    # @return [Hash] { available: true, total_cost:, input_cost:, output_cost: }
    #             or { available: false } when pricing is unavailable
    def self.calculate(model_id:, input_tokens:, output_tokens:)
      return { available: false } unless model_id && defined?(RubyLLM::Models)

      model_info = RubyLLM::Models.find(model_id)
      return { available: false } unless model_info

      input_price  = model_info.respond_to?(:input_price_per_million)  ? model_info.input_price_per_million  : nil
      output_price = model_info.respond_to?(:output_price_per_million) ? model_info.output_price_per_million : nil
      return { available: false } unless input_price && output_price

      input_cost  = input_tokens  * input_price  / 1_000_000.0
      output_cost = output_tokens * output_price / 1_000_000.0

      { available: true, total_cost: input_cost + output_cost, input_cost: input_cost, output_cost: output_cost }
    rescue StandardError => e
      { available: false, error: e.message }
    end
  end
end
