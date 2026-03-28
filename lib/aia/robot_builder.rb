# frozen_string_literal: true

# lib/aia/robot_builder.rb
#
# Builds a single RobotLab::Robot from AIA configuration.
# Extracted from RobotFactory to isolate single-robot construction.

module AIA
  class RobotBuilder
    class << self
      # Build a single robot for one model spec.
      #
      # @param config [AIA::Config]
      # @param namer [RobotNamer]
      # @return [RobotLab::Robot]
      def build(config, namer:)
        model_spec  = config.models.first
        robot_name  = namer.name_for(model_spec.name)
        roster      = [{ name: robot_name, spec: model_spec }]
        identity    = SystemPromptAssembler.build_identity_prompt(robot_name, model_spec, roster)
        base_prompt = SystemPromptAssembler.resolve_system_prompt(config, model_spec)
        system_prompt = [identity, base_prompt].compact.join("\n\n")

        build_opts = {
          name:          robot_name,
          system_prompt: system_prompt,
          model:         model_spec.name,
          local_tools:   ToolLoader.filtered_tools(config),
          mcp_servers:   Array(config.mcp_servers).map { |s| MCPConfigNormalizer.normalize(s) },
          on_content:    nil,
          config:        RobotFactory.build_run_config(config)
        }
        build_opts[:provider] = RobotFactory.send(:resolve_provider, model_spec) if model_spec.provider

        RobotLab.build(**build_opts)
      end
    end
  end
end
