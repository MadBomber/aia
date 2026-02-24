# frozen_string_literal: true

# lib/aia/session_tracker.rb
#
# Tracks session metrics and outcomes for the learning loop.
# Records per-turn data: model, tokens, cost, latency, decisions.

module AIA
  class SessionTracker
    attr_reader :turn_count, :total_cost, :total_tokens, :turns

    def initialize
      @turn_count = 0
      @total_cost = 0.0
      @total_tokens = 0
      @turns = []
    end

    # Record a completed turn.
    #
    # @param model [String] model used
    # @param input [String] user input
    # @param result the LLM response
    # @param decisions [AIA::Decisions, nil] routing decisions for this turn
    def record_turn(model:, input:, result:, decisions: nil)
      @turn_count += 1

      metrics = extract_metrics(result)
      @total_cost += metrics[:cost]
      @total_tokens += metrics[:tokens]

      @turns << {
        model: model,
        input_length: input.to_s.length,
        tokens: metrics[:tokens],
        cost: metrics[:cost],
        latency: metrics[:latency],
        decisions: decisions&.to_h,
        timestamp: Time.now
      }
    end

    # Record a model switch event.
    #
    # @param from [String] previous model
    # @param to [String] new model
    # @param reason [String] reason for the switch
    def record_model_switch(from:, to:, reason: "user_request")
      @turns << {
        type: :model_switch,
        from: from,
        to: to,
        reason: reason,
        timestamp: Time.now
      }
    end

    # Record user feedback on the last response.
    #
    # @param satisfied [Boolean] whether the user was satisfied
    def record_user_feedback(satisfied:)
      return if @turns.empty?
      @turns.last[:user_satisfied] = satisfied
    end

    # Export session stats as a hash for KBS fact assertion.
    #
    # @return [Hash] session statistics
    def to_facts
      {
        turn_count: @turn_count,
        total_cost: @total_cost,
        total_tokens: @total_tokens
      }
    end

    # Reset all tracked data.
    def reset!
      @turn_count = 0
      @total_cost = 0.0
      @total_tokens = 0
      @turns.clear
    end

    private

    def extract_metrics(result)
      if result.respond_to?(:output) && result.output.respond_to?(:any?) && result.output.any?
        last_msg = result.output.last
        tokens = 0
        cost = 0.0

        if last_msg.respond_to?(:input_tokens)
          input_tokens = last_msg.input_tokens || 0
          output_tokens = last_msg.output_tokens || 0
          tokens = input_tokens + output_tokens

          cost = compute_cost(result, input_tokens, output_tokens)
        end

        { tokens: tokens, cost: cost, latency: 0 }
      else
        { tokens: 0, cost: 0.0, latency: 0 }
      end
    end

    # Compute cost from token counts and model pricing.
    # Falls back to 0.0 if pricing info is unavailable.
    def compute_cost(result, input_tokens, output_tokens)
      model_id = if result.respond_to?(:robot_name)
                   result.robot_name
                 elsif result.respond_to?(:model_id)
                   result.model_id
                 end

      return 0.0 unless model_id && defined?(RubyLLM::Models)

      model_info = RubyLLM::Models.find(model_id)
      return 0.0 unless model_info

      input_price = model_info.respond_to?(:input_price_per_million) ? (model_info.input_price_per_million || 0) : 0
      output_price = model_info.respond_to?(:output_price_per_million) ? (model_info.output_price_per_million || 0) : 0

      (input_tokens * input_price / 1_000_000.0) + (output_tokens * output_price / 1_000_000.0)
    rescue StandardError
      0.0
    end
  end
end
