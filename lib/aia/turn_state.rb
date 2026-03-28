# frozen_string_literal: true

# lib/aia/turn_state.rb
#
# Request-scoped state object for inter-component signaling.
# Replaces ad-hoc instance variable flags on AIA.config.
#
# Only one special mode may be requested per turn (mutual exclusion).
# Use TurnState#request(mode, **opts) to enqueue a mode — this clears
# all other force_* flags before setting the new one. Assigning the
# attr_accessors directly bypasses mutual exclusion (for backward compat
# and direct test assertions).

module AIA
  class TurnState
    # Exclusive mode flags — only one may be active at a time via #request.
    EXCLUSIVE_MODES = %i[
      verify decompose concurrent_mcp debate delegate spawn
    ].freeze

    attr_accessor :force_verify, :force_decompose, :force_concurrent_mcp,
                  :force_debate, :force_delegate, :force_spawn, :spawn_type,
                  :active_mcp_servers, :active_tools

    def initialize
      clear!
    end

    # Request a special mode for this turn.
    # Clears all other exclusive force_* flags before activating the new mode,
    # enforcing mutual exclusion at the point of enqueue.
    #
    # @param mode [Symbol] one of EXCLUSIVE_MODES
    # @param type [String, nil] specialist type (only relevant for :spawn)
    # @raise [ArgumentError] if mode is not one of EXCLUSIVE_MODES
    def request(mode, type: nil)
      unless EXCLUSIVE_MODES.include?(mode)
        raise ArgumentError, "Unknown TurnState mode: #{mode.inspect}. Valid: #{EXCLUSIVE_MODES.join(', ')}"
      end

      clear_exclusive_flags!

      case mode
      when :verify         then @force_verify         = true
      when :decompose      then @force_decompose       = true
      when :concurrent_mcp then @force_concurrent_mcp = true
      when :debate         then @force_debate          = true
      when :delegate       then @force_delegate        = true
      when :spawn          then @force_spawn = true; @spawn_type = type
      end
    end

    def clear!
      @force_verify        = false
      @force_decompose     = false
      @force_concurrent_mcp = false
      @force_debate        = false
      @force_delegate      = false
      @force_spawn         = false
      @spawn_type          = nil
      @active_mcp_servers  = nil
      @active_tools        = nil
    end

    # Returns which exclusive mode is currently active, or nil if none.
    def active_mode
      return :verify         if @force_verify
      return :decompose      if @force_decompose
      return :concurrent_mcp if @force_concurrent_mcp
      return :debate         if @force_debate
      return :delegate       if @force_delegate
      return :spawn          if @force_spawn
      nil
    end

    private

    def clear_exclusive_flags!
      @force_verify         = false
      @force_decompose      = false
      @force_concurrent_mcp = false
      @force_debate         = false
      @force_delegate       = false
      @force_spawn          = false
      @spawn_type           = nil
    end
  end
end
