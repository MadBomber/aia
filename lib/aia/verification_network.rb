# frozen_string_literal: true

# lib/aia/verification_network.rb
#
# Self-review via consensus: two robots independently answer,
# then a reconciler compares and produces a verified answer.
#
# With two or more models configured, the verifiers use different models
# (and a third model, when given, reconciles). An optional temperature delta
# moves verifier-a below and verifier-b above the configured temperature so
# the two answers genuinely diverge.

module AIA
  class VerificationNetwork
    TEMPERATURE_RANGE = (0.0..1.0)

    class << self
      # Build a verification network for the given config.
      #
      # @param config the AIA configuration
      # @param temperature_delta [Numeric, nil] subtracted from the configured
      #   temperature for verifier-a and added for verifier-b (clamped to 0.0..1.0);
      #   nil keeps the configured temperature for both
      # @return [RobotLab::Network] a consensus network with verifiers + reconciler
      # :reek:TooManyStatements -- builds three robots, each with its own model and run config
      def build(config, temperature_delta: nil)
        model_a, model_b, reconciler_model = assign_models(config.models)
        run_config = RobotFactory.build_run_config(config)
        config_a, config_b = verifier_run_configs(run_config, temperature_delta)
        tools = ToolLoader.filtered_tools(config)
        mcp = RobotFactory.mcp_servers(config)

        RobotLab.create_network(name: "aia-verification") do
          worker_a = RobotFactory.build_robot(
            model_a,
            name:          "verifier-a",
            system_prompt: "Answer the following question. Be thorough and precise.",
            local_tools:   tools,
            mcp:           mcp,
            config:        config_a
          )
          task :verify_a, worker_a, depends_on: :none

          worker_b = RobotFactory.build_robot(
            model_b,
            name:          "verifier-b",
            system_prompt: "Answer the following question independently. " \
                           "Focus on correctness and completeness.",
            local_tools:   tools,
            mcp:           mcp,
            config:        config_b
          )
          task :verify_b, worker_b, depends_on: :none

          reconciler = RobotFactory.build_robot(
            reconciler_model,
            name:          "reconciler",
            system_prompt: "Compare two independent answers to the same question. " \
                           "Identify agreements and disagreements. " \
                           "Produce a final, reconciled answer that is most accurate. " \
                           "Note any areas of uncertainty.",
            config:        run_config
          )
          task :reconcile, reconciler, depends_on: %i[verify_a verify_b]
        end
      end

      # Models for verifier-a, verifier-b and the reconciler.
      #
      #   1 model  -> [m0, m0, m0]
      #   2 models -> [m0, m1, m0]
      #   3+       -> [m0, m1, m2]
      def assign_models(models)
        first = models.first
        [first, models[1] || first, models[2] || first]
      end

      # Run configs for verifier-a and verifier-b. The delta is only applied
      # when the base run config sets a temperature (models that reject
      # temperature get none).
      def verifier_run_configs(run_config, delta)
        base = run_config.to_h[:temperature]
        return [run_config, run_config] unless delta && base

        [
          run_config.merge(temperature: clamp_temperature(base - delta)),
          run_config.merge(temperature: clamp_temperature(base + delta))
        ]
      end

      def clamp_temperature(value)
        value.to_f.clamp(TEMPERATURE_RANGE.min, TEMPERATURE_RANGE.max).round(4)
      end
    end
  end
end
