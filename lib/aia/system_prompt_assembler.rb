# frozen_string_literal: true

# lib/aia/system_prompt_assembler.rb
#
# System prompt resolution, identity prompts, and role loading.
# Extracted from RobotFactory to isolate the prompt assembly concern.
# Completely stateless — no module ivars.

module AIA
  module SystemPromptAssembler
    module_function

    # Resolve system prompt from config (including role).
    #
    # @param config [AIA::Config] the AIA configuration
    # @param model_spec [ModelSpec, nil] optional model spec with role override
    # @return [String, nil] the assembled system prompt
    def resolve_system_prompt(config, model_spec = nil)
      system_prompt = config.prompts.system_prompt

      role_id = model_spec&.role || config.prompts.role
      if role_id && !role_id.empty?
        role_content = load_role_content(config, role_id)
        if role_content
          system_prompt = [system_prompt, role_content].compact.join("\n\n")
        end
      end

      system_prompt
    end

    # Build a system prompt fragment that tells a robot its name, its
    # model, and the other robots in the network.
    #
    # @param robot_name [String] this robot's creative name
    # @param spec [ModelSpec] this robot's model spec
    # @param roster [Array<Hash>] all robots: [{ name:, spec: }, ...]
    # @return [String]
    def build_identity_prompt(robot_name, spec, roster)
      provider_label = spec.provider ? " (#{spec.provider})" : ""
      lines = ["You are #{robot_name}, powered by #{spec.name}#{provider_label}."]

      if roster.size > 1
        lines << "You are part of a team of AI robots:"
        roster.each do |entry|
          p = entry[:spec].provider ? " (#{entry[:spec].provider})" : ""
          marker = entry[:name] == robot_name ? " ← you" : ""
          lines << "  - #{entry[:name]}: #{entry[:spec].name}#{p}#{marker}"
        end
        lines << "Users can address a specific robot with @name mentions."
      end

      lines.join("\n")
    end

    # Load role file content.
    #
    # @param config [AIA::Config] the AIA configuration
    # @param role_id [String] the role identifier
    # @return [String, nil] the role file content or nil
    def load_role_content(config, role_id)
      roles_prefix = config.prompts.roles_prefix
      unless role_id.start_with?(roles_prefix)
        role_id = "#{roles_prefix}/#{role_id}"
      end

      role_file = File.join(config.prompts.dir, "#{role_id}#{config.prompts.extname}")
      return nil unless File.exist?(role_file)

      File.read(role_file)
    rescue => e
      warn "Warning: Could not load role '#{role_id}': #{e.message}"
      nil
    end
  end
end
