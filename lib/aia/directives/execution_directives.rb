# frozen_string_literal: true

# lib/aia/directives/execution_directives.rb

require 'shellwords'

module AIA
  class ExecutionDirectives < Directive
    desc "Execute Ruby code"
    def ruby(args, context_manager = nil)
      ruby_code = args.join(' ')

      begin
        String(eval(ruby_code))
      rescue StandardError => e
        <<~ERROR
          This ruby code failed: #{ruby_code}
          #{e.message}
        ERROR
      end
    end
    alias_method :rb, :ruby

    desc "Use text-to-speech to speak the text"
    def say(args, context_manager = nil)
      system('say', *args)
      ""
    end

    desc "Execute next prompt with concurrent MCP server access"
    def concurrent(args, context_manager = nil)
      AIA.turn_state.force_concurrent_mcp = true
      "Concurrent MCP mode enabled for next prompt."
    end
    alias_method :conc, :concurrent

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
    alias_method :del, :delegate

    desc "Spawn a specialist robot for the next prompt"
    def spawn(args, context_manager = nil)
      AIA.turn_state.force_spawn = true
      AIA.turn_state.spawn_type = args.first
      type_msg = args.first ? " (#{args.first})" : " (auto-detect)"
      "Spawn mode enabled#{type_msg} for next prompt."
    end

    desc "3-tier layered orchestration: orchestrator → lead agents → specialists"
    def orchestrate(args, context_manager = nil)
      AIA.turn_state.force_orchestrate = true
      "Orchestration mode enabled. Your next prompt is the application requirements."
    end
    alias_method :orch, :orchestrate
  end
end
