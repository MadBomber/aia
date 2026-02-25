# frozen_string_literal: true

# lib/aia/spawn_handler.rb
#
# Dynamically creates specialist robots using robot_lab's spawn().
# The primary robot determines what kind of specialist is needed,
# spawns it on the shared bus, and collects the response.
# Specialists are cached for reuse within the session.

module AIA
  class SpawnHandler
    include ContentExtractor

    def initialize(robot:, ui_presenter:, tracker:)
      @robot        = robot
      @ui_presenter = ui_presenter
      @tracker      = tracker
      @spawned      = {}
    end

    attr_writer :robot

    # Spawn a specialist robot to handle a prompt.
    #
    # @param prompt [String]
    # @param specialist_type [String, nil] explicit type or nil for auto-detect
    # @return [String, nil] specialist's response
    def handle(prompt, specialist_type: nil)
      primary = @robot.is_a?(RobotLab::Network) ? @robot.robots.values.first : @robot
      primary.with_bus unless primary.respond_to?(:bus) && primary.bus

      role, instruction = if specialist_type
                            [specialist_type, "You are a #{specialist_type} specialist. Answer precisely within your domain of expertise."]
                          else
                            detect_specialist(primary, prompt)
                          end

      # Spawn or reuse specialist
      specialist = @spawned[role] ||= primary.spawn(
        name:          role,
        system_prompt: instruction
      )

      @ui_presenter.display_info("Specialist '#{role}' responding...")

      result  = specialist.run(prompt, mcp: :inherit, tools: :inherit)
      content = extract_reply(result)

      # Track in TrakFlow if available
      if AIA.task_coordinator&.available?
        AIA.task_coordinator.create_task(
          "Specialist: #{prompt[0, 60]}",
          assignee: role,
          labels:   ["specialist", "spawned"],
          creator:  primary.name
        )
      end

      @tracker.record_turn(
        model: AIA.config.models.first.name,
        input: prompt,
        result: result
      )

      content
    end

    private

    def detect_specialist(primary, prompt)
      @ui_presenter.display_info("Determining specialist type...")

      result = primary.run(<<~PROMPT, mcp: :none, tools: :none)
        What type of specialist would best answer this question?
        Reply with exactly two lines:
        Line 1: specialist role (e.g., security_expert, data_scientist)
        Line 2: one-sentence instruction for the specialist

        Question: #{prompt}
      PROMPT

      reply = extract_reply(result)
      lines = reply.strip.split("\n", 2)
      role        = lines[0]&.strip&.downcase&.gsub(/\s+/, "_") || "specialist"
      instruction = lines[1]&.strip || "You are a #{role}."

      [role, instruction]
    end

    def extract_reply(result)
      result.respond_to?(:reply) ? result.reply : result.to_s
    end
  end
end
