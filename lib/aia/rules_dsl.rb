# frozen_string_literal: true

# lib/aia/rules_dsl.rb
#
# Provides AIA.rules_for(:kb_name) API for user rule targeting.
# Users write rules in ~/.config/aia/rules/*.rb targeting specific KBs.

module AIA
  # Accumulated user rules, organized by target KB
  @user_rules = Hash.new { |h, k| h[k] = [] }

  class << self
    # Register rules targeting a specific knowledge base.
    #
    # @param kb_name [Symbol] the KB to target (:classify, :model_select, :route, :gate, :learn)
    # @yield block containing rule definitions using the KBS DSL
    #
    # @example
    #   AIA.rules_for(:model_select) do
    #     rule "prefer_claude_for_ruby" do
    #       on :classification, domain: "code"
    #       perform do |facts|
    #         suggest type: :model_decision, model: "claude-sonnet-4-20250514"
    #       end
    #     end
    #   end
    def rules_for(kb_name, &block)
      @user_rules[kb_name] << block
    end

    # Access the accumulated user rules hash
    def user_rules
      @user_rules
    end

    # Clear all registered user rules (used in testing)
    def clear_user_rules!
      @user_rules.clear
    end
  end
end
