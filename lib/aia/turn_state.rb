# frozen_string_literal: true

# lib/aia/turn_state.rb
#
# Request-scoped state object for inter-component signaling.
# Replaces ad-hoc instance variable flags on AIA.config.
# Flags are set by directives (/verify, /decompose, /concurrent)
# and consumed by ChatLoop or Session on the next prompt.

module AIA
  class TurnState
    attr_accessor :force_verify, :force_decompose, :force_concurrent_mcp

    def initialize
      clear!
    end

    def clear!
      @force_verify = false
      @force_decompose = false
      @force_concurrent_mcp = false
    end
  end
end
