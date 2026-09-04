# frozen_string_literal: true

# lib/aia/directives/execution_directives.rb

require 'shellwords'

module AIA
  class ExecutionDirectives < Directive
    state_setting! :concurrent, :conc, :verify, :decompose, :debate,
                   :delegate, :del, :spawn, :orchestrate, :orch,
                   :add_recruit, :add, :drop_recruit, :drop, :reskill

    desc "Execute Ruby code (requires allow_ruby_eval: true in config)"
    def ruby(args, context_manager = nil)
      unless AIA.config.flags.allow_ruby_eval
        puts "ERROR: /ruby is disabled. Set `allow_ruby_eval: true` in " \
             "~/.aia/config.yml or pass --allow-ruby-eval to enable it. " \
             "Note: this executes arbitrary Ruby with full process privileges."
        return ""
      end

      ruby_code = args.join(' ')
      $stderr.puts "WARNING: /ruby executing: #{ruby_code}"

      begin
        String(eval(ruby_code))  # rubocop:disable Security/Eval
      rescue StandardError => e
        <<~ERROR
          This ruby code failed: #{ruby_code}
          #{e.message}
        ERROR
      end
    end
    alias rb ruby

    desc "Use text-to-speech to speak the text"
    def say(args, context_manager = nil)
      audio = AIA.config.audio
      voice = audio.voice
      env   = {}
      env['SPEECH_MODEL'] = audio.speech_model if audio.speech_model
      if voice && !voice.strip.empty?
        system(env, 'say', '-v', voice, *args)
      else
        system(env, 'say', *args)
      end
      ""
    end

    desc "Execute next prompt with concurrent MCP server access"
    def concurrent(args, context_manager = nil)
      AIA.turn_state.force_concurrent_mcp = true
      "Concurrent MCP mode enabled for next prompt."
    end
    alias conc concurrent

    desc "Run next prompt through verification (two independent answers + reconciliation)"
    def verify(args, context_manager = nil)
      AIA.turn_state.force_verify = true
      "Verification mode enabled for next prompt."
    end

    desc "Decompose next prompt into parallel sub-tasks"
    def decompose(args, context_manager = nil)
      AIA.turn_state.force_decompose = true
      "Decomposition mode enabled for next prompt."
    end

    desc "Multi-round debate between robots in the network"
    def debate(args, context_manager = nil)
      AIA.turn_state.force_debate = true
      "Debate mode enabled for next prompt."
    end

    desc "Delegate subtasks to specific robots via TrakFlow plan"
    def delegate(args, context_manager = nil)
      AIA.turn_state.force_delegate = true
      "Delegation mode enabled for next prompt."
    end
    alias del delegate

    desc "Spawn a specialist robot for the next prompt. " \
         "Usage: /spawn  |  /spawn <type>  |  /spawn <name> <provider/model> <system prompt>"
    def spawn(args, context_manager = nil)
      state = AIA.turn_state
      state.force_spawn = true

      if args.size >= 2
        spec = AIA::SpawnSpecParser.parse(args)
        state.spawn_spec = spec
        state.spawn_type = nil
        "Spawn mode enabled: '#{spec[:name]}' (#{spawn_model_summary(spec)}) for next prompt."
      else
        type = args.first
        state.spawn_spec = nil
        state.spawn_type = type
        type_msg = type ? " (#{type})" : " (auto-detect)"
        "Spawn mode enabled#{type_msg} for next prompt."
      end
    end

    desc "Recruit a robot into the crew (persists, @mention-able). Usage: " \
         "/add_recruit <name> [provider/model] [skill:<id>...] [system prompt]  (alias: /add)"
    def add_recruit(args, context_manager = nil)
      return "Usage: /add_recruit <name> [provider/model] [skill:<id> ...] [system prompt]" if args.empty?

      spec = args.size >= 2 ? AIA::SpawnSpecParser.parse(args) : { name: args[0] }
      robot = AIA::Crew.recruit(spec)
      "Recruited '#{robot.name}' into the crew (#{recruit_summary(spec)})."
    rescue AIA::CrewError => e
      "Recruit failed: #{e.message}"
    end
    alias add add_recruit

    desc "Drop a robot from the crew. Usage: /drop_recruit <name>  (alias: /drop)"
    def drop_recruit(args, context_manager = nil)
      return "Usage: /drop_recruit <name>" if args.empty?

      AIA::Crew.drop(args.first)
      "Dropped '#{args.first}' from the crew."
    rescue AIA::CrewError => e
      "Drop failed: #{e.message}"
    end
    alias drop drop_recruit

    desc "Reset a crew member to a clean slate and re-skill it. " \
         "Usage: /reskill <name> [skill:<id>...] [system prompt]"
    def reskill(args, context_manager = nil)
      return "Usage: /reskill <name> [skill:<id> ...] [system prompt]" if args.empty?

      skills, rest = AIA::SpawnSpecParser.extract_skills(args[1..].to_a)
      prompt = rest.join(' ').strip
      robot = AIA::Crew.reskill(args.first, skills: skills, system_prompt: (prompt.empty? ? nil : prompt))
      suffix = skills.empty? ? '' : " with #{skills.join(', ')}"
      "Reskilled '#{robot.name}'#{suffix} (clean slate)."
    rescue AIA::CrewError => e
      "Reskill failed: #{e.message}"
    end

    desc "3-tier layered orchestration: orchestrator → lead agents → specialists"
    def orchestrate(args, context_manager = nil)
      AIA.turn_state.force_orchestrate = true
      "Orchestration mode enabled. Your next prompt is the application requirements."
    end
    alias orch orchestrate

    private

    # Human-readable model description for the /spawn confirmation message.
    def spawn_model_summary(spec)
      model = spec[:model]
      return 'inherited model' unless model

      spec[:provider] ? "#{spec[:provider]}/#{model}" : model
    end

    # Model plus any assigned skills, for the /add_recruit confirmation message.
    def recruit_summary(spec)
      parts  = [spawn_model_summary(spec)]
      skills = Array(spec[:skills])
      parts << "skills: #{skills.join(', ')}" unless skills.empty?
      parts.join('; ')
    end
  end
end
