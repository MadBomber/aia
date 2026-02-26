# frozen_string_literal: true

# lib/aia/rule_router.rb
#
# Multi-KB rule router for intelligent prompt/model/tool routing.
# Uses KBS (Knowledge-Based System) with separate knowledge bases
# for each concern: classification, model selection, MCP routing,
# quality gates, and post-response learning.

require 'kbs/dsl'
require_relative 'decisions'
require_relative 'rules_dsl'

module AIA
  class RuleRouter
    KB_ORDER = [:classify, :model_select, :route, :gate].freeze
    POST_RESPONSE_KBS = [:learn].freeze

    attr_reader :decisions

    # Keyword patterns used to classify tools into domains.
    # Applied against "#{tool_name} #{tool_description}".
    # Keys must match domains produced by the classify KB.
    TOOL_DOMAIN_PATTERNS = {
      "code"     => /\b(code|execute|eval|script|shell|command|programming|ruby|python|javascript|compile|lint)\b/i,
      "data"     => /(sql|database|\bquery\b|\btable\b|\bschema\b|\brecord\b|\bcsv\b|\bjson\b|data[\s_-]?(base|set|store|source)|\bredis\b|\bmongo)/i,
      "file"     => /\b(file|directory|disk|folder|path)\b/i,
      "web"      => /\b(browser|web\s*page|url|http|visit|scrape|screenshot|html)\b/i,
      "image"    => /\b(image|picture|photo|diagram|visual|svg|png|graphic|draw)\b/i,
      "planning" => /\b(task|project|plan|schedule|workflow|roadmap|milestone|kanban|todo)\b/i,
      "audio"    => /\b(audio|sound|music|voice|speech|transcri)\b/i,
      "system"   => /\b(brew|homebrew|package|install|system|os|process|service|daemon|apt|yum|dnf|pip|npm|gem)\b/i,
    }.freeze

    # Domains that don't have a classify KB rule get input-text-based
    # classification rules built dynamically alongside the route rules.
    # These are the domains already covered by build_classification_kb.
    BUILTIN_CLASSIFY_DOMAINS = %w[code data image planning audio].freeze

    def initialize
      @decisions = Decisions.new
      AIA.decisions = @decisions
      @knowledge_bases = {}
      @tools_registered = false
      @domain_tool_names = {}  # populated by register_tools for /rules display
      build_all_kbs
      load_user_rules
    end

    # Register loaded tools and dynamically build routing rules.
    # Called by Session after RobotFactory.build discovers tools.
    #
    # @param tools [Array] loaded tool classes (RubyLLM::Tool subclasses)
    def register_tools(tools)
      return if tools.nil? || tools.empty? || @tools_registered

      domain_tools = map_tools_to_domains(tools)
      server_tools = map_tools_to_mcp_servers(tools)

      build_dynamic_classify_rules(domain_tools)
      build_dynamic_tool_rules(domain_tools)
      build_mcp_server_classify_rules(server_tools)
      build_mcp_server_route_rules(server_tools)

      @tools_registered = true
      @domain_tool_names = domain_tools.transform_values { |v| v.dup.freeze }.freeze
      @server_tool_names = server_tools.transform_values { |v| v.dup.freeze }.freeze

      log_tool_domain_mapping(domain_tools)
      log_mcp_server_mapping(server_tools)
    end

    # Return decompiled rule source for all KBs.
    #
    # @param filter [String, nil] optional substring filter on rule name or source
    # @return [Hash{Symbol => Array<Hash>}] kb_name → [{name:, source:}]
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
        assert_facts_for(kb, kb_name, config, input)
        assert_decision_facts(kb, kb_name)
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
      assert_response_facts(kb, outcome)
      kb.run
    rescue StandardError => e
      warn "Warning: Post-response learning failed: #{e.message}"
    end

    private

    # =========================================================================
    # KB Construction
    # =========================================================================

    def build_all_kbs
      @knowledge_bases[:classify]     = build_classification_kb
      @knowledge_bases[:model_select] = build_model_selection_kb
      @knowledge_bases[:route]        = build_routing_kb
      @knowledge_bases[:gate]         = build_quality_gate_kb
      @knowledge_bases[:learn]        = build_learning_kb
    end

    # KB 1: Input Classification
    # Categorizes user prompts by domain, complexity, and intent.
    def build_classification_kb
      decisions = @decisions

      KBS.knowledge_base do
        # Domain classification rules
        rule "code_request" do
          on :turn_input do
            text matches(/\b(refactor|debug|implement|function|class|method|test|bug|fix|compile|lint)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "code", source: "code_request")
          end
        end

        rule "data_request" do
          on :turn_input do
            text matches(/(sql|database|\bquery\b|\btable\b|\bschema\b|\brecord\b|\bselect\b|\binsert\b|\bmigration\b|\bredis\b|\bmongo)/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "data", source: "data_request")
          end
        end

        rule "image_request" do
          on :turn_input do
            text matches(/\b(draw|image|picture|diagram|generate.*image|create.*image|photo|illustration)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "image", source: "image_request")
          end
        end

        rule "planning_request" do
          on :turn_input do
            text matches(/\b(plan|task|project|roadmap|milestone|schedule|workflow|organize|prioritize)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "planning", source: "planning_request")
          end
        end

        # Context-based classification
        rule "image_context_detection" do
          on :context_file, extension: one_of('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp')
          perform do |facts|
            decisions.add(:classification, domain: "image", source: "image_context")
          end
        end

        rule "audio_context_detection" do
          on :context_file, extension: one_of('.mp3', '.wav', '.ogg', '.m4a', '.flac', '.aac')
          perform do |facts|
            decisions.add(:classification, domain: "audio", source: "audio_context")
          end
        end

        rule "code_context_detection" do
          on :context_file, extension: one_of('.rb', '.py', '.js', '.ts', '.go', '.rs', '.java', '.c', '.cpp', '.swift')
          perform do |facts|
            decisions.add(:classification, domain: "code", source: "code_context")
          end
        end

        # Complexity classification
        rule "short_factual_query" do
          on :turn_input do
            length less_than(100)
          end
          perform do |facts|
            decisions.add(:classification, domain: "general", complexity: "low", source: "short_query")
          end
        end

        rule "complex_query" do
          on :turn_input do
            length greater_than(500)
          end
          perform do |facts|
            decisions.add(:classification, complexity: "high", source: "long_query")
          end
        end

        # Intent detection for model switching
        rule "model_switch_request" do
          on :turn_input do
            text matches(/\b(switch|use|try|change)\b.*\b(to|model)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_switch",
              raw_text: facts[0][:text], source: "model_switch_request")
          end
        end

        rule "model_compare_request" do
          on :turn_input do
            text matches(/\b(compare|hear from|also.*ask|get.*opinion)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_compare",
              raw_text: facts[0][:text], source: "model_compare_request")
          end
        end

        rule "cheaper_model_request" do
          on :turn_input do
            text matches(/\b(cheap|fast|quick|budget|less expensive|save)\b.*\b(model|one)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_switch_capability",
              capability: "cheap", raw_text: facts[0][:text], source: "cheaper_model_request")
          end
        end

        rule "better_model_request" do
          on :turn_input do
            text matches(/\b(best|better|smart|powerful|premium)\b.*\b(model|one)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_switch_capability",
              capability: "best", raw_text: facts[0][:text], source: "better_model_request")
          end
        end
      end
    end

    # KB 2: Model Selection
    # Reads classification decisions and matches to model capabilities.
    def build_model_selection_kb
      decisions = @decisions

      KBS.knowledge_base do
        rule "vision_model_needed" do
          on :classification_decision, domain: "image"
          on :model, supports_vision: true
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "vision capability needed")
          end
        end

        rule "audio_model_needed" do
          on :classification_decision, domain: "audio"
          on :model, supports_audio: true
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "audio capability needed")
          end
        end

        rule "cheap_model_for_simple" do
          on :classification_decision, complexity: "low"
          on :model, cost_tier: "low"
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "simple query — save cost")
          end
        end

        rule "powerful_model_for_complex" do
          on :classification_decision, complexity: "high"
          on :model, cost_tier: satisfies { |t| t == "high" || t == "premium" }
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "complex query — needs capable model")
          end
        end
      end
    end

    # KB 3: MCP/Tool Routing
    # MCP routing rules are built-in (MCP servers declare topics).
    # Tool routing rules are built dynamically by register_tools()
    # after RobotFactory discovers the actual loaded tools.
    def build_routing_kb
      decisions = @decisions

      KBS.knowledge_base do
        rule "code_mcp_routing" do
          on :classification_decision, domain: "code"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("code") || t.include?("files")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "code domain")
          end
        end

        rule "data_mcp_routing" do
          on :classification_decision, domain: "data"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("data") || t.include?("sql")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "data domain")
          end
        end

        rule "planning_mcp_routing" do
          on :classification_decision, domain: "planning"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("planning") || t.include?("tasks")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "planning domain")
          end
        end

        rule "search_mcp_routing" do
          on :classification_decision, domain: "general"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("search") || t.include?("web")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "general search")
          end
        end
      end
    end

    # KB 4: Quality Gates
    # Pre-send checks that can warn or block.
    def build_quality_gate_kb
      decisions = @decisions

      KBS.knowledge_base do
        rule "prompt_too_vague" do
          on :turn_input do
            length less_than(10)
          end
          perform do |facts|
            decisions.add(:gate, action: "warn",
              message: "Prompt seems vague. Consider adding more detail.")
          end
        end

        rule "large_context_warning" do
          on :context_stats, large: true
          perform do |facts|
            decisions.add(:gate, action: "warn",
              message: "Context exceeds 100KB. Consider a model with a larger context window.")
          end
        end

        rule "cost_warning" do
          on :session_stats, total_cost: greater_than(5.0)
          perform do |facts|
            decisions.add(:gate, action: "warn",
              message: "Session cost is over $5. Consider a cheaper model.")
          end
        end
      end
    end

    # KB 5: Post-Response Learning
    # Runs after LLM responds to track outcomes.
    def build_learning_kb
      decisions = @decisions

      KBS.knowledge_base do
        rule "track_model_switch" do
          on :response_outcome, user_switched_model: true
          perform do |facts|
            decisions.add(:learning, signal: "model_dissatisfaction",
              model: facts[0][:model])
          end
        end

        rule "track_success" do
          on :response_outcome, accepted: true
          perform do |facts|
            decisions.add(:learning, signal: "model_success",
              model: facts[0][:model])
          end
        end

        rule "cost_tracking" do
          on :session_stats, total_cost: greater_than(0)
          perform do |facts|
            decisions.add(:learning, signal: "cost_update",
              total: facts[0][:total_cost])
          end
        end
      end
    end

    # =========================================================================
    # Dynamic Tool Rule Generation
    # =========================================================================

    # Classify each tool into domains by matching name + description
    # against TOOL_DOMAIN_PATTERNS.
    #
    # @param tools [Array] loaded tool classes
    # @return [Hash{String => Array<String>}] domain → tool names
    def map_tools_to_domains(tools)
      domain_tools = Hash.new { |h, k| h[k] = [] }

      tools.each do |tool_class|
        name = tool_name(tool_class)
        desc = tool_description(tool_class)
        text = "#{name} #{desc}"

        TOOL_DOMAIN_PATTERNS.each do |domain, pattern|
          domain_tools[domain] << name if text.match?(pattern)
        end
      end

      # "file" domain tools are also useful for "code" tasks
      if domain_tools.key?("file")
        domain_tools["code"] = (domain_tools["code"] + domain_tools["file"]).uniq
      end

      domain_tools
    end

    # For domains that don't have built-in classify rules (e.g. "web", "file"),
    # add classification rules so user input can trigger those domains.
    def build_dynamic_classify_rules(domain_tools)
      kb = @knowledge_bases[:classify]
      return unless kb

      decisions = @decisions

      domain_tools.each_key do |domain|
        next if BUILTIN_CLASSIFY_DOMAINS.include?(domain)

        pattern = TOOL_DOMAIN_PATTERNS[domain]
        next unless pattern

        kb.rule "#{domain}_request" do
          on :turn_input do
            text matches(pattern)
          end
          perform do |_facts|
            decisions.add(:classification, domain: domain, source: "#{domain}_request")
          end
        end
      end
    end

    # Build route KB rules that activate tools when their domain matches
    # the classified input domain.
    def build_dynamic_tool_rules(domain_tools)
      kb = @knowledge_bases[:route]
      return unless kb

      decisions = @decisions

      domain_tools.each do |domain, tool_names|
        next if tool_names.empty?

        names = tool_names.dup.freeze

        kb.rule "activate_#{domain}_tools" do
          on :classification_decision, domain: domain
          on :tool, name: satisfies { |n| names.include?(n.to_s) }
          perform do |facts|
            decisions.add(:tool_activate,
              tool: facts[1][:name],
              reason: "#{domain} domain")
          end
        end
      end
    end

    # Group MCP tools by their server name.
    #
    # @param tools [Array] all loaded tools
    # @return [Hash{String => Array<String>}] server_name → tool names
    def map_tools_to_mcp_servers(tools)
      server_tools = Hash.new { |h, k| h[k] = [] }

      tools.each do |tool|
        server = tool.respond_to?(:mcp) ? tool.mcp : nil
        next unless server

        name = tool_name(tool)
        server_tools[server.to_s] << name
      end

      server_tools
    end

    # Build classify rules that detect MCP server names in the user input.
    # E.g. if user says "brew info", classify as domain "mcp:brew".
    def build_mcp_server_classify_rules(server_tools)
      kb = @knowledge_bases[:classify]
      return unless kb

      decisions = @decisions

      server_tools.each_key do |server_name|
        # Build a pattern that matches the server name as a word in the input
        escaped = Regexp.escape(server_name)
        pattern = /\b#{escaped}\b/i

        kb.rule "mcp_server_#{server_name}_request" do
          on :turn_input do
            text matches(pattern)
          end
          perform do |_facts|
            decisions.add(:classification, domain: "mcp:#{server_name}", source: "mcp_server_match")
          end
        end
      end
    end

    # Build route rules that activate all tools for a matched MCP server.
    def build_mcp_server_route_rules(server_tools)
      kb = @knowledge_bases[:route]
      return unless kb

      decisions = @decisions

      server_tools.each do |server_name, tool_names|
        next if tool_names.empty?

        names = tool_names.dup.freeze

        kb.rule "activate_mcp_#{server_name}_tools" do
          on :classification_decision, domain: "mcp:#{server_name}"
          on :tool, name: satisfies { |n| names.include?(n.to_s) }
          perform do |facts|
            decisions.add(:tool_activate,
              tool: facts[1][:name],
              reason: "mcp:#{server_name} server")
          end
        end
      end
    end

    def log_tool_domain_mapping(domain_tools)
      return if domain_tools.empty?

      $stderr.puts "\n[KBS] Tool domain mapping:"
      domain_tools.each do |domain, tool_names|
        next if tool_names.empty?
        $stderr.puts "  #{domain}: #{tool_names.join(', ')}"
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
      parts << "tools=#{tool_acts.join(',')}" if tool_acts.any?
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
    # Fact Assertion
    # =========================================================================

    def assert_facts_for(kb, kb_name, config, input)
      case kb_name
      when :classify
        assert_context_facts(kb, config)
        assert_turn_facts(kb, input) if input
      when :model_select
        assert_model_facts(kb, config)
      when :route
        assert_mcp_facts(kb, config)
        assert_tool_facts(kb, config)
        assert_turn_facts(kb, input) if input
      when :gate
        assert_context_stats(kb, config)
        assert_turn_facts(kb, input) if input
        assert_session_facts(kb)
      end
    end

    # Assert upstream decisions as facts for downstream KBs
    def assert_decision_facts(kb, kb_name)
      case kb_name
      when :model_select
        @decisions.classifications.each do |c|
          kb.assert(:classification_decision, **c)
        end
      when :route
        @decisions.classifications.each do |c|
          kb.assert(:classification_decision, **c)
        end
        @decisions.model_decisions.each do |m|
          kb.assert(:model_decision_upstream, **m)
        end
      when :gate
        @decisions.model_decisions.each do |m|
          kb.assert(:model_decision, **m)
        end
      end
    end

    def assert_context_facts(kb, config)
      Array(config.context_files).each do |file|
        ext = File.extname(file).downcase
        kb.assert(:context_file,
          path: file,
          extension: ext,
          exists: File.exist?(file)
        )
      end
    end

    def assert_context_stats(kb, config)
      total_size = Array(config.context_files).sum do |f|
        File.exist?(f) ? File.size(f) : 0
      end
      kb.assert(:context_stats,
        total_size: total_size,
        large: total_size > 100_000
      )
    end

    def assert_model_facts(kb, config)
      config.models.each do |spec|
        model_info = find_model_info(spec.name)

        if model_info
          kb.assert(:model,
            name:            spec.name,
            role:            spec.role,
            provider:        model_info_provider(model_info),
            context_window:  model_info_context_window(model_info),
            supports_vision: model_info_vision(model_info),
            supports_audio:  model_info_audio(model_info),
            cost_tier:       classify_cost(model_info)
          )
        else
          kb.assert(:model, name: spec.name, role: spec.role)
        end
      end
    end

    def assert_mcp_facts(kb, config)
      return if config.flags&.no_mcp

      Array(config.mcp_servers).each do |server|
        kb.assert(:mcp_server,
          name:   server[:name] || server["name"],
          topics: server[:topics] || server["topics"] || [],
          active: true
        )
      end
    end

    def assert_tool_facts(kb, config)
      tools = all_registered_tools(config)
      tools.each do |tool_class|
        name = tool_name(tool_class)
        desc = tool_description(tool_class)
        kb.assert(:tool,
          name:        name,
          description: desc,
          active:      true
        )
      end
    end

    # Collect local + MCP tools so route rules can match against all of them.
    def all_registered_tools(config)
      local = Array(config.loaded_tools)
      mcp   = collect_robot_mcp_tools
      local + mcp
    end

    # Retrieve MCP tools from the active robot (or first robot in a Network).
    def collect_robot_mcp_tools
      robot = AIA.client
      return [] unless robot

      return Array(robot.mcp_tools) if robot.respond_to?(:mcp_tools)

      if robot.respond_to?(:robots) && robot.robots.is_a?(Hash)
        first = robot.robots.values.first
        return Array(first.mcp_tools) if first
      end

      []
    end

    def assert_turn_facts(kb, input)
      kb.assert(:turn_input,
        text: input,
        length: input.length
      )
    end

    def assert_session_facts(kb)
      tracker = AIA.session_tracker
      return unless tracker

      kb.assert(:session_stats, **tracker.to_facts)
    end

    def assert_response_facts(kb, outcome)
      kb.assert(:response_outcome, **outcome) if outcome.is_a?(Hash) && outcome.any?

      tracker = AIA.session_tracker
      kb.assert(:session_stats, **tracker.to_facts) if tracker
    end

    # =========================================================================
    # Model Info Helpers
    # =========================================================================

    def find_model_info(model_name)
      return nil unless defined?(RubyLLM) && RubyLLM.respond_to?(:models)
      RubyLLM.models.find(model_name)
    rescue StandardError
      nil
    end

    def model_info_provider(info)
      info.respond_to?(:provider) ? info.provider : nil
    end

    def model_info_context_window(info)
      info.respond_to?(:context_window) ? info.context_window : nil
    end

    def model_info_vision(info)
      if info.respond_to?(:supports?)
        info.supports?(:vision)
      else
        false
      end
    rescue StandardError
      false
    end

    def model_info_audio(info)
      if info.respond_to?(:supports?)
        info.supports?(:audio)
      else
        false
      end
    rescue StandardError
      false
    end

    def classify_cost(model_info)
      input_cost = if model_info.respond_to?(:input_price_per_million)
                     model_info.input_price_per_million || 0
                   else
                     0
                   end

      case input_cost
      when 0..1     then "low"
      when 1..10    then "medium"
      when 10..50   then "high"
      else               "premium"
      end
    end

    # =========================================================================
    # Tool Info Helpers
    # =========================================================================

    def tool_name(tool_class)
      if tool_class.respond_to?(:name)
        tool_class.name.to_s
      else
        tool_class.to_s
      end
    end

    def tool_description(tool_class)
      if tool_class.respond_to?(:description)
        tool_class.description.to_s
      else
        ""
      end
    rescue StandardError
      ""
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
