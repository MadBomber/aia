# frozen_string_literal: true

# lib/aia/rule_router.rb
#
# Multi-KB rule router for intelligent prompt/model/tool routing.
# Uses KBS (Knowledge-Based System) with separate knowledge bases
# for each concern: classification, model selection, MCP routing,
# quality gates, and post-response learning.

require 'kbs/dsl'
require_relative 'decisions'
require_relative 'fact_asserter'
require_relative 'rules_dsl'
require_relative 'kb_definitions'
require_relative 'dynamic_rule_builder'

module AIA
  class RuleRouter
    KB_ORDER = [:classify, :model_select, :route, :gate].freeze
    POST_RESPONSE_KBS = [:learn].freeze

    attr_reader :decisions

    def initialize
      @decisions = Decisions.new
      @fact_asserter = FactAsserter.new
      AIA.decisions = @decisions
      @knowledge_bases = KBDefinitions.build_all_kbs(@decisions)
      @tools_registered = false
      @domain_tool_names = {}
      load_user_rules
    end

    # Register loaded tools and dynamically build routing rules.
    # Called by Session after RobotFactory.build discovers tools.
    #
    # @param tools [Array] loaded tool classes (RubyLLM::Tool subclasses)
    def register_tools(tools)
      return if tools.nil? || tools.empty? || @tools_registered

      result = DynamicRuleBuilder.register(
        @knowledge_bases, @decisions, @fact_asserter, tools
      )

      @tools_registered = true
      @domain_tool_names = result[:domain_tools].transform_values { |entries|
        entries.map { |e| e[:name] }.freeze
      }.freeze
      @server_tool_names = result[:server_tools].transform_values { |v| v.dup.freeze }.freeze

      log_tool_domain_mapping(result[:domain_tools])
      log_mcp_server_mapping(result[:server_tools])
    end

    # Return decompiled rule source for all KBs.
    #
    # @param filter [String, nil] optional substring filter on rule name or source
    # @return [Hash{Symbol => Array<Hash>}] kb_name => [{name:, source:}]
    def rules_source(filter = nil)
      result = {}

      @knowledge_bases.each do |kb_name, kb|
        entries = kb.rules.keys.filter_map do |name|
          source = kb.rule_source(name) || "(no source available)"
          searchable = "#{kb_name} #{name} #{source}".downcase

          next if filter && !searchable.include?(filter)

          { name: name, source: source }
        end

        result[kb_name] = entries unless entries.empty?
      end

      result
    end

    # Evaluate pre-send rules against the current configuration.
    # Called once before RobotFactory.build and per chat turn.
    #
    # @param config the AIA configuration
    # @param input [String, nil] optional user input text
    # @return [AIA::Decisions] the accumulated decisions
    def evaluate(config, input = nil)
      return @decisions unless config.rules&.enabled

      @decisions.clear!

      KB_ORDER.each do |kb_name|
        kb = @knowledge_bases[kb_name]
        next unless kb

        reset_kb(kb)
        @fact_asserter.assert_facts_for(kb, kb_name, config, input)
        @fact_asserter.assert_decision_facts(kb, kb_name, @decisions)
        kb.run
      end

      apply_decisions(config)
      log_turn_decisions(input) if input
      @decisions
    rescue StandardError => e
      warn "Warning: Rule evaluation failed: #{e.message}"
      @decisions
    end

    # Evaluate rules for a single chat turn.
    # Called before each robot.run(input) in the chat loop.
    #
    # @param config the AIA configuration
    # @param input [String] the user's chat input
    # @return [AIA::Decisions] the accumulated decisions
    def evaluate_turn(config, input)
      evaluate(config, input)
    end

    # Run post-response learning rules after the LLM responds.
    #
    # @param config the AIA configuration
    # @param outcome [Hash] response outcome data
    def evaluate_response(config, outcome = {})
      return unless config.rules&.enabled

      kb = @knowledge_bases[:learn]
      return unless kb

      kb.reset
      @fact_asserter.assert_response_facts(kb, outcome)
      kb.run
    rescue StandardError => e
      warn "Warning: Post-response learning failed: #{e.message}"
    end

    private

    def log_tool_domain_mapping(domain_tools)
      return if domain_tools.empty?

      $stderr.puts "\n[KBS] Tool domain mapping:"
      domain_tools.each do |domain, tool_entries|
        next if tool_entries.empty?

        by_server = tool_entries.group_by { |e| e[:server] || 'local' }
        parts = by_server.map { |srv, entries| "#{srv}(#{entries.map { |e| e[:name] }.join(', ')})" }
        $stderr.puts "  #{domain}: #{parts.join(', ')}"
      end
      $stderr.puts
    end

    def log_mcp_server_mapping(server_tools)
      return if server_tools.empty?

      $stderr.puts "[KBS] MCP server tool groups:"
      server_tools.each do |server, tool_names|
        $stderr.puts "  #{server}: #{tool_names.size} tools"
      end
      $stderr.puts
    end

    # Log per-turn KBS decisions to stderr so they're visible.
    def log_turn_decisions(input)
      classifications = @decisions.classifications
      tool_acts       = @decisions.activated_tools
      mcp_acts        = @decisions.activated_mcp_servers
      gates           = @decisions.gate_actions

      parts = []
      if classifications.any?
        domains = classifications.map { |c| c[:domain] }.compact.uniq
        parts << "domains=#{domains.join(',')}" if domains.any?
      end
      if tool_acts.any?
        by_server = @decisions.tool_activations.group_by { |a| a[:server] || 'local' }
        tool_parts = by_server.map { |srv, acts| "#{srv}:#{acts.map { |a| a[:tool] }.join(',')}" }
        parts << "tools=#{tool_parts.join(' + ')}"
      end
      parts << "mcp=#{mcp_acts.join(',')}" if mcp_acts.any?
      gates.each { |g| parts << "gate:#{g[:action]}" }

      if parts.any?
        $stderr.puts "[KBS] #{parts.join(' | ')}"
      else
        $stderr.puts "[KBS] No rules matched for this turn"
      end
    end

    # =========================================================================
    # User Rule Loading
    # =========================================================================

    def load_user_rules
      load_user_rule_files
      apply_targeted_user_rules
    end

    def load_user_rule_files
      rules_dir = AIA.config&.rules&.dir
      return unless rules_dir

      rules_dir = File.expand_path(rules_dir)
      return unless Dir.exist?(rules_dir)

      Dir.glob(File.join(rules_dir, '*.rb')).sort.each do |rule_file|
        load rule_file
      rescue StandardError => e
        warn "Warning: Failed to load rule file '#{rule_file}': #{e.message}"
      end
    end

    def apply_targeted_user_rules
      AIA.user_rules.each do |kb_name, blocks|
        kb = @knowledge_bases[kb_name]
        next unless kb

        blocks.each do |block|
          kb.instance_eval(&block)
        rescue StandardError => e
          warn "Warning: Failed to apply user rule for KB '#{kb_name}': #{e.message}"
        end
      end
    end

    # =========================================================================
    # KB Reset
    # =========================================================================

    def reset_kb(kb)
      kb.reset
    end

    # =========================================================================
    # Decision Application
    # =========================================================================

    def apply_decisions(config)
      # Block gates are enforced here as a safety backstop.
      # Warn gates, model/MCP decisions, and learning signals
      # are handled by DecisionApplier in ChatLoop and Session.
      @decisions.gate_actions.each do |gate|
        raise AIA::GateError, gate[:message] if gate[:action] == "block"
      end
    end
  end
end
