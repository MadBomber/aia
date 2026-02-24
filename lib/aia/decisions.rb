# frozen_string_literal: true

# lib/aia/decisions.rb
#
# Typed container for rule engine outputs.
# Each KB writes its suggestions here; downstream KBs read them as input.

module AIA
  class Decisions
    attr_reader :classifications, :model_decisions, :mcp_activations,
                :gate_actions, :learnings

    def initialize
      @classifications  = []
      @model_decisions  = []
      @mcp_activations  = []
      @gate_actions     = []
      @learnings        = []
    end

    def add(type, **attrs)
      case type
      when :classification  then @classifications  << attrs
      when :model_decision  then @model_decisions  << attrs
      when :mcp_activate    then @mcp_activations  << attrs
      when :gate            then @gate_actions      << attrs
      when :learning        then @learnings         << attrs
      end
    end

    def has_any?(type)
      collection = collection_for(type)
      collection ? collection.any? : false
    end

    def clear!
      @classifications.clear
      @model_decisions.clear
      @mcp_activations.clear
      @gate_actions.clear
      @learnings.clear
    end

    def to_h
      {
        classifications: @classifications.dup,
        model_decisions: @model_decisions.dup,
        mcp_activations: @mcp_activations.dup,
        gate_actions:    @gate_actions.dup,
        learnings:       @learnings.dup
      }
    end

    private

    def collection_for(type)
      case type
      when :classification  then @classifications
      when :model_decision  then @model_decisions
      when :mcp_activate    then @mcp_activations
      when :gate            then @gate_actions
      when :learning        then @learnings
      end
    end
  end
end
