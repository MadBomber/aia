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
        model_spec    = config.models.first
        robot_name    = namer.name_for(model_spec.name)
        roster        = [{ name: robot_name, spec: model_spec }]
        identity      = SystemPromptAssembler.build_identity_prompt(robot_name, model_spec, roster)
        base_prompt   = SystemPromptAssembler.resolve_system_prompt(config, model_spec)
        thinking_note = thinking_mode_instruction(model_spec)
        system_prompt = [identity, base_prompt, thinking_note].compact.join("\n\n")

        RobotFactory.build_robot(
          model_spec,
          name:          robot_name,
          system_prompt: system_prompt,
          local_tools:   ToolLoader.filtered_tools(config),
          mcp_servers:   RobotFactory.mcp_server_configs(config),
          on_content:    nil,
          config:        RobotFactory.build_run_config(config)
        )
      end

      private

      # Local thinking-mode models (e.g. qwen3 on Ollama) sometimes generate
      # reasoning content but leave the response section empty, causing the user
      # to receive only raw thinking text. This instruction nudges the model to
      # always emit a plain-text answer after its reasoning.
      def thinking_mode_instruction(model_spec)
        return nil unless model_spec&.local_provider?

        "After completing your reasoning, always write a clear, complete response " \
          "in plain text. Never leave your response empty after thinking — your " \
          "answer must appear outside the thinking block."
      end
    end
  end
end
