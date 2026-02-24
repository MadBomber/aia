# frozen_string_literal: true

# lib/aia/expert_router.rb
#
# Routes prompts to specialist robots based on KBS classification.
# When expert routing is enabled, builds a specialist robot with
# the model and MCP servers appropriate for the classified domain.

module AIA
  class ExpertRouter
    # @param decisions [AIA::Decisions] the accumulated KBS decisions
    def initialize(decisions)
      @decisions = decisions
    end

    # Route to a specialist robot based on classification decisions.
    # Returns nil if no specialist routing is needed.
    #
    # @param config the AIA configuration
    # @return [RobotLab::Robot, nil] a specialist robot or nil
    def route(config)
      classification = @decisions.classifications.find { |c| c[:domain] }
      return nil unless classification

      model_decision = @decisions.model_decisions.first
      mcp_activations = @decisions.mcp_activations

      # Only build a specialist if we have routing recommendations
      return nil unless model_decision || mcp_activations.any?

      build_specialist(config, classification, model_decision, mcp_activations)
    rescue StandardError => e
      warn "Warning: Expert routing failed: #{e.message}"
      nil
    end

    private

    def build_specialist(config, classification, model_decision, mcp_activations)
      model_name = model_decision&.dig(:model) || config.models.first.name

      mcp_configs = select_mcp_configs(config, mcp_activations)

      RobotLab.build(
        name:          "aia-expert-#{classification[:domain]}",
        system_prompt: RobotFactory.resolve_system_prompt(config),
        model:         model_name,
        local_tools:   RobotFactory.filtered_tools(config),
        mcp_servers:   mcp_configs.map { |s| RobotFactory.normalize_mcp_config(s) },
        config:        RobotFactory.build_run_config(config)
      )
    end

    def select_mcp_configs(config, mcp_activations)
      if mcp_activations.any?
        activated_names = mcp_activations.map { |a| a[:server] }
        (config.mcp_servers || []).select do |s|
          name = s[:name] || s["name"]
          activated_names.include?(name)
        end
      else
        config.mcp_servers || []
      end
    end
  end
end
