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
    # For network results (SimpleFlow::Result), records one entry per
    # robot so the /cost directive can show per-model breakdowns.
    #
    # @param model [String] model used (ignored for network results)
    # @param input [String] user input
    # @param result the LLM response
    # @param decisions [Hash, nil] routing decisions for this turn
    # @param elapsed [Float, nil] seconds the model took to respond
    def record_turn(model:, input:, result:, decisions: nil, elapsed: nil)
      if defined?(SimpleFlow::Result) && result.is_a?(SimpleFlow::Result)
        record_network_turn(input: input, flow_result: result, decisions: decisions, elapsed: elapsed)
        return
      end

      @turn_count += 1

      metrics = extract_metrics(result)
      @total_cost += metrics[:cost]
      @total_tokens += metrics[:tokens]

      @turns << {
        model: model,
        input_length: input.to_s.length,
        input_tokens: metrics[:input_tokens],
        output_tokens: metrics[:output_tokens],
        tokens: metrics[:tokens],
        cost: metrics[:cost],
        elapsed: elapsed || 0,
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

    # Expand a network SimpleFlow::Result into one turn entry per robot.
    # Computes TF-IDF similarity of each response against the first.
    def record_network_turn(input:, flow_result:, decisions: nil, elapsed: nil)
      @turn_count += 1
      now = Time.now

      # Collect robot data in order for similarity scoring
      robot_entries = []
      response_texts = []

      flow_result.context.each do |task_name, robot_result|
        next if task_name == :run_params
        next unless robot_result.respond_to?(:raw)

        raw = robot_result.raw
        input_tokens  = (raw&.respond_to?(:input_tokens) && raw.input_tokens) || 0
        output_tokens = (raw&.respond_to?(:output_tokens) && raw.output_tokens) || 0
        tokens = input_tokens + output_tokens

        model_id = extract_model_id_from_raw(raw)
        model_id ||= robot_result.respond_to?(:robot_name) ? robot_result.robot_name : task_name.to_s

        cost = tokens > 0 ? compute_cost_for_model(model_id, input_tokens, output_tokens) : 0.0
        robot_elapsed = robot_result.respond_to?(:duration) ? (robot_result.duration || 0) : 0

        text = if robot_result.respond_to?(:reply)
                 robot_result.reply.to_s
               elsif robot_result.respond_to?(:content)
                 robot_result.content.to_s
               else
                 ""
               end
        response_texts << text

        robot_entries << {
          model: model_id,
          input_length: input.to_s.length,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          tokens: tokens,
          cost: cost,
          elapsed: robot_elapsed,
          decisions: decisions&.to_h,
          timestamp: now
        }
      end

      # Compute similarity scores (first model is reference)
      scores = if robot_entries.size > 1
                 SimilarityScorer.score(response_texts)
               else
                 Array.new(robot_entries.size)
               end

      robot_entries.each_with_index do |entry, i|
        entry[:similarity] = scores[i]
        @total_cost += entry[:cost]
        @total_tokens += entry[:tokens]
        @turns << entry
      end
    end

    def extract_model_id_from_raw(raw)
      return nil unless raw
      return raw.model_id if raw.respond_to?(:model_id) && raw.model_id
      return raw.model    if raw.respond_to?(:model)    && raw.model
      nil
    end

    def compute_cost_for_model(model_id, input_tokens, output_tokens)
      result = CostCalculator.calculate(model_id: model_id, input_tokens: input_tokens, output_tokens: output_tokens)
      result[:available] ? result[:total_cost] : 0.0
    end

    def extract_metrics(result)
      input_tokens = 0
      output_tokens = 0

      # Prefer raw RubyLLM::Message (has token data); fall back to output messages
      source = if result.respond_to?(:raw) && result.raw.respond_to?(:input_tokens)
                 result.raw
               elsif result.respond_to?(:output) && result.output.respond_to?(:last)
                 result.output.last
               end

      if source&.respond_to?(:input_tokens) && source.input_tokens
        input_tokens = source.input_tokens || 0
        output_tokens = source.output_tokens || 0
      end

      tokens = input_tokens + output_tokens
      cost = tokens > 0 ? compute_cost(result, input_tokens, output_tokens) : 0.0

      { input_tokens: input_tokens, output_tokens: output_tokens, tokens: tokens, cost: cost }
    end

    # Compute cost from token counts and model pricing.
    # Falls back to 0.0 if pricing info is unavailable.
    def compute_cost(result, input_tokens, output_tokens)
      model_id = if result.respond_to?(:robot_name)
                   result.robot_name
                 elsif result.respond_to?(:model_id)
                   result.model_id
                 end
      compute_cost_for_model(model_id, input_tokens, output_tokens)
    end
  end
end
