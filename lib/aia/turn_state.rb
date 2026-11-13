# frozen_string_literal: true

# lib/aia/turn_state.rb
#
# Request-scoped state object for inter-component signaling.
# Replaces ad-hoc instance variable flags on AIA.config.
#
# Only one special mode may be requested per turn (mutual exclusion).
# TurnState#request(mode, **opts) enqueues a mode and clears all other
# force_* flags. #consume! hands the active mode to its handler and
# clears it. The force_* flags are read-only from outside.

module AIA
  # :reek:TooManyInstanceVariables -- one boolean flag per exclusive mode plus spawn details; a Hash would lose the attr_accessor API
  class TurnState
    # Exclusive mode flags — only one may be active at a time via #request.
    EXCLUSIVE_MODES = %i[
      verify decompose concurrent_mcp debate delegate spawn orchestrate
    ].freeze

    attr_reader :force_verify, :force_decompose, :force_concurrent_mcp,
                :force_debate, :force_delegate, :force_spawn, :spawn_type,
                :spawn_spec, :force_orchestrate, :verify_delta

    def initialize
      clear!
    end

    # Request a special mode for this turn.
    # Clears all other exclusive force_* flags before activating the new mode,
    # enforcing mutual exclusion at the point of enqueue.
    #
    # @param mode [Symbol] one of EXCLUSIVE_MODES
    # @param type [String, nil] specialist type (only relevant for :spawn)
    # @param spec [Hash, nil] explicit specialist spec (only relevant for :spawn)
    # @param delta [Numeric, nil] verifier temperature delta (only relevant for :verify)
    # @raise [ArgumentError] if mode is not one of EXCLUSIVE_MODES
    def request(mode, type: nil, spec: nil, delta: nil)
      unless EXCLUSIVE_MODES.include?(mode)
        raise ArgumentError, "Unknown TurnState mode: #{mode.inspect}. Valid: #{EXCLUSIVE_MODES.join(', ')}"
      end

      clear_exclusive_flags!

      case mode
      when :verify         then @force_verify = true
                                @verify_delta = delta
      when :decompose      then @force_decompose = true
      when :concurrent_mcp then @force_concurrent_mcp = true
      when :debate         then @force_debate          = true
      when :delegate       then @force_delegate        = true
      when :spawn          then @force_spawn = true
                                @spawn_type = type
                                @spawn_spec = spec
      when :orchestrate    then @force_orchestrate     = true
      end
    end

    # Take the active mode for handling and clear it.
    #
    # @return [Hash, nil] { mode:, spawn_type:, spawn_spec:, verify_delta: }, or nil when no mode is active
    def consume!
      mode = active_mode
      return nil unless mode

      taken = { mode: mode, spawn_type: @spawn_type, spawn_spec: @spawn_spec, verify_delta: @verify_delta }
      clear_exclusive_flags!
      taken
    end

    # Clear +mode+ if it is the active mode; leave any other mode alone.
    #
    # @param mode [Symbol] one of EXCLUSIVE_MODES
    def clear_mode(mode)
      clear_exclusive_flags! if active_mode == mode
    end

    def clear!
      @force_verify        = false
      @force_decompose     = false
      @force_concurrent_mcp = false
      @force_debate        = false
      @force_delegate      = false
      @force_spawn         = false
      @spawn_type          = nil
      @spawn_spec          = nil
      @force_orchestrate   = false
      @verify_delta        = nil
    end

    # Returns which exclusive mode is currently active, or nil if none.
    def active_mode
      return :verify         if @force_verify
      return :decompose      if @force_decompose
      return :concurrent_mcp if @force_concurrent_mcp
      return :debate         if @force_debate
      return :delegate       if @force_delegate
      return :spawn          if @force_spawn
      return :orchestrate    if @force_orchestrate
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
      @spawn_spec           = nil
      @force_orchestrate    = false
      @verify_delta         = nil
    end
  end
end
