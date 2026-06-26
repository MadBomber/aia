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
    include HandlerProtocol

    MAX_CACHE_SIZE = 5

    def initialize(robot:, ui_presenter:, tracker:)
      @robot        = robot
      @ui_presenter = ui_presenter
      @tracker      = tracker
      @spawned      = {}
    end

    attr_writer :robot

    # Release all cached specialist robots.
    def cleanup!
      @spawned.clear
    end

    # Spawn a specialist robot to handle a prompt.
    #
    # @param context [HandlerContext] — reads context.prompt, context.specialist_type,
    #   and context.spawn_spec (explicit {name:, model:, provider:, system_prompt:})
    # @return [String, nil] specialist's response
    def handle(context)
      prompt  = context.prompt
      primary = @robot.chief
      primary.with_bus unless primary.respond_to?(:bus) && primary.bus

      role, instruction, spawn_opts = resolve_specialist(context, primary, prompt)

      # Spawn or reuse specialist (evict oldest when cache is full)
      specialist = @spawned[role] ||= begin
        evict_oldest! if @spawned.size >= MAX_CACHE_SIZE
        primary.spawn(name: role, system_prompt: instruction, **spawn_opts)
      end

      @ui_presenter.display_info("Specialist '#{role}' responding...")

      result  = specialist.run(prompt, mcp: :inherit, tools: :inherit)
      content = extract_content(result)

      # Track in TrakFlow if available
      if AIA.task_coordinator&.available?
        AIA.task_coordinator.create_task(
          "Specialist: #{prompt[0, 60]}",
          assignee: role,
          labels:   %w[specialist spawned],
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

    # Decide the specialist's role, system prompt, and any model/provider
    # override, from (in priority order): an explicit /spawn spec, an explicit
    # specialist type, or LLM auto-detection.
    #
    # @return [Array(String, String, Hash)] [role, instruction, spawn_opts]
    def resolve_specialist(context, primary, prompt)
      if (spec = context.spawn_spec)
        role        = spec[:name]
        instruction = spec[:system_prompt] || "You are #{role}."
        [role, instruction, model_opts(spec)]
      elsif (type = context.specialist_type)
        [type, "You are a #{type} specialist. Answer precisely within your domain of expertise.", {}]
      else
        role, instruction = detect_specialist(primary, prompt)
        [role, instruction, {}]
      end
    end

    # Model/provider override for an explicit spawn. When a model is given we
    # pass the provider too (even nil) so it overrides the inherited parent
    # provider — e.g. spawning a cloud model from a local-model parent. With no
    # model, the spawned robot inherits its parent's model and provider.
    #
    # @return [Hash]
    def model_opts(spec)
      return {} unless spec[:model]

      { model: spec[:model], provider: spec[:provider] }
    end

    def evict_oldest!
      @spawned.delete(@spawned.keys.first)
    end

    def detect_specialist(primary, prompt)
      @ui_presenter.display_info("Determining specialist type...")

      result = primary.run(<<~PROMPT, mcp: :none, tools: :none)
        What type of specialist would best answer this question?
        Reply with exactly two lines:
        Line 1: specialist role (e.g., security_expert, data_scientist)
        Line 2: one-sentence instruction for the specialist

        Question: #{prompt}
      PROMPT

      reply = extract_content(result)
      lines = reply.strip.split("\n", 2)
      role        = lines[0]&.strip&.downcase&.gsub(/\s+/, "_") || "specialist"
      instruction = lines[1]&.strip || "You are a #{role}."

      [role, instruction]
    end
  end
end
