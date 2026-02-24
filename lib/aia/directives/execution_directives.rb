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
  end
end
