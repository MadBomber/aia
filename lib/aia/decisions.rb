# frozen_string_literal: true

# lib/aia/decisions.rb
#
# Typed container for rule engine outputs.
# Each KB writes its suggestions here; downstream KBs read them as input.

module AIA
  class Decisions
    attr_reader :classifications, :model_decisions, :mcp_activations,
                :tool_activations, :gate_actions, :learnings

    def initialize
      @classifications   = []
      @model_decisions   = []
      @mcp_activations   = []
      @tool_activations  = []
      @gate_actions      = []
      @learnings         = []
    end

    def add(type, **attrs)
      case type
      when :classification  then @classifications   << attrs
      when :model_decision
        raise ArgumentError, "model_decision requires a non-nil :model (got #{attrs.inspect})" if attrs[:model].nil?
        @model_decisions << attrs
      when :mcp_activate    then @mcp_activations   << attrs
      when :tool_activate   then @tool_activations  << attrs
      when :gate            then @gate_actions       << attrs
      when :learning        then @learnings          << attrs
      end
    end

    def has_any?(type)
      collection = collection_for(type)
      collection ? collection.any? : false
    end

    # Returns the first model_decision's model name, or nil
    def recommended_model
      @model_decisions.first&.dig(:model)
    end

    # Returns array of activated MCP server names
    def activated_mcp_servers
      @mcp_activations.map { |a| a[:server] }
    end

    # Returns array of activated tool names (deduplicated)
    def activated_tools
      @tool_activations.map { |a| a[:tool] }.uniq
    end

    # Returns tool activations grouped by MCP server name
    def activated_tools_by_server
      @tool_activations.group_by { |a| a[:server] }
    end

    # Returns gate warnings only (excludes blocks)
    def gate_warnings
      @gate_actions.select { |g| g[:action] == "warn" }
    end

    # Returns gate blocks only
    def gate_blocks
      @gate_actions.select { |g| g[:action] == "block" }
    end

    def clear!
      @classifications.clear
      @model_decisions.clear
      @mcp_activations.clear
      @tool_activations.clear
      @gate_actions.clear
      @learnings.clear
    end

    def to_h
      {
        classifications:  @classifications.dup,
        model_decisions:  @model_decisions.dup,
        mcp_activations:  @mcp_activations.dup,
        tool_activations: @tool_activations.dup,
        gate_actions:     @gate_actions.dup,
        learnings:        @learnings.dup
      }
    end

    private

    def collection_for(type)
      case type
      when :classification  then @classifications
      when :model_decision  then @model_decisions
      when :mcp_activate    then @mcp_activations
      when :tool_activate   then @tool_activations
      when :gate            then @gate_actions
      when :learning        then @learnings
      end
    end
  end
end
