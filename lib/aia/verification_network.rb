# frozen_string_literal: true

# lib/aia/verification_network.rb
#
# Self-review via consensus: two robots independently answer,
# then a reconciler compares and produces a verified answer.

module AIA
  class VerificationNetwork
    # Build a verification network for the given config.
    #
    # @param config the AIA configuration
    # @return [RobotLab::Network] a consensus network with verifiers + reconciler
    def self.build(config)
      model = config.models.first
      run_config = RobotFactory.send(:build_run_config, config)
      tools = RobotFactory.send(:filtered_tools, config)
      mcp = RobotFactory.send(:mcp_server_configs, config)

      RobotLab.create_network(name: "aia-verification") do
        worker_a = RobotLab.build(
          name:          "verifier-a",
          model:         model.name,
          system_prompt: "Answer the following question. Be thorough and precise.",
          local_tools:   tools,
          mcp_servers:   mcp,
          config:        run_config
        )
        task :verify_a, worker_a, depends_on: :none

        worker_b = RobotLab.build(
          name:          "verifier-b",
          model:         model.name,
          system_prompt: "Answer the following question independently. " \
                         "Focus on correctness and completeness.",
          local_tools:   tools,
          mcp_servers:   mcp,
          config:        run_config
        )
        task :verify_b, worker_b, depends_on: :none

        reconciler = RobotLab.build(
          name:          "reconciler",
          model:         model.name,
          system_prompt: "Compare two independent answers to the same question. " \
                         "Identify agreements and disagreements. " \
                         "Produce a final, reconciled answer that is most accurate. " \
                         "Note any areas of uncertainty.",
          config:        run_config
        )
        task :reconcile, reconciler, depends_on: [:verify_a, :verify_b]
      end
    end
  end
end
