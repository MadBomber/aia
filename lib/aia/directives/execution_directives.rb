# frozen_string_literal: true

# lib/aia/directives/execution_directives.rb

require 'shellwords'

module AIA
  class ExecutionDirectives < Directive
    state_setting! :concurrent, :conc, :verify, :decompose, :debate,
                   :delegate, :del, :spawn, :orchestrate, :orch

    desc "Execute Ruby code (requires allow_ruby_eval: true in config)"
    def ruby(args, context_manager = nil)
      unless AIA.config.flags.allow_ruby_eval
        return "ERROR: /ruby is disabled. Set `allow_ruby_eval: true` in " \
               "~/.aia/config.yml or pass --allow-ruby-eval to enable it. " \
               "Note: this executes arbitrary Ruby with full process privileges."
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
      env   = {}
      env['SPEECH_MODEL'] = audio.speech_model if audio.speech_model
      if audio.voice && !audio.voice.strip.empty?
        system(env, 'say', '-v', audio.voice, *args)
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
      AIA.turn_state.force_spawn = true

      if args.size >= 2
        spec = AIA::SpawnSpecParser.parse(args)
        AIA.turn_state.spawn_spec = spec
        AIA.turn_state.spawn_type = nil
        "Spawn mode enabled: '#{spec[:name]}' (#{spawn_model_summary(spec)}) for next prompt."
      else
        AIA.turn_state.spawn_spec = nil
        AIA.turn_state.spawn_type = args.first
        type_msg = args.first ? " (#{args.first})" : " (auto-detect)"
        "Spawn mode enabled#{type_msg} for next prompt."
      end
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
      return 'inherited model' unless spec[:model]

      spec[:provider] ? "#{spec[:provider]}/#{spec[:model]}" : spec[:model]
    end
  end
end
