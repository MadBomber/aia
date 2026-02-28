# frozen_string_literal: true

# lib/aia/dynamic_rule_builder.rb
#
# Dynamically generates KBS rules that map loaded tools to domains
# and MCP servers. Called after RobotFactory discovers tools.
# Extracted from RuleRouter to improve single-responsibility.

module AIA
  module DynamicRuleBuilder
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

    module_function

    # Orchestrate the full dynamic rule registration flow.
    #
    # @param knowledge_bases [Hash{Symbol => KBS::KnowledgeBase}]
    # @param decisions [AIA::Decisions]
    # @param fact_asserter [AIA::FactAsserter]
    # @param tools [Array] loaded tool classes
    # @return [Hash] { domain_tools: Hash, server_tools: Hash }
    def register(knowledge_bases, decisions, fact_asserter, tools)
      domain_tools = map_tools_to_domains(tools, fact_asserter)
      server_tools = map_tools_to_mcp_servers(tools, fact_asserter)

      build_dynamic_classify_rules(knowledge_bases[:classify], decisions, domain_tools)
      build_dynamic_tool_rules(knowledge_bases[:route], decisions, domain_tools)
      build_mcp_server_classify_rules(knowledge_bases[:classify], decisions, server_tools)
      build_mcp_server_route_rules(knowledge_bases[:route], decisions, server_tools)

      { domain_tools: domain_tools, server_tools: server_tools }
    end

    # Classify each tool into domains by matching name + description
    # against TOOL_DOMAIN_PATTERNS.
    #
    # @param tools [Array] loaded tool classes
    # @param fact_asserter [AIA::FactAsserter]
    # @return [Hash{String => Array<String>}] domain => tool names
    def map_tools_to_domains(tools, fact_asserter)
      domain_tools = Hash.new { |h, k| h[k] = [] }

      tools.each do |tool_class|
        name = fact_asserter.tool_name(tool_class)
        desc = fact_asserter.tool_description(tool_class)
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
    #
    # @param kb [KBS::KnowledgeBase] the classify KB
    # @param decisions [AIA::Decisions]
    # @param domain_tools [Hash{String => Array<String>}]
    def build_dynamic_classify_rules(kb, decisions, domain_tools)
      return unless kb

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
    #
    # @param kb [KBS::KnowledgeBase] the route KB
    # @param decisions [AIA::Decisions]
    # @param domain_tools [Hash{String => Array<String>}]
    def build_dynamic_tool_rules(kb, decisions, domain_tools)
      return unless kb

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
    # @param fact_asserter [AIA::FactAsserter]
    # @return [Hash{String => Array<String>}] server_name => tool names
    def map_tools_to_mcp_servers(tools, fact_asserter)
      server_tools = Hash.new { |h, k| h[k] = [] }

      tools.each do |tool|
        server = tool.respond_to?(:mcp) ? tool.mcp : nil
        next unless server

        name = fact_asserter.tool_name(tool)
        server_tools[server.to_s] << name
      end

      server_tools
    end

    # Build classify rules that detect MCP server names in the user input.
    # E.g. if user says "brew info", classify as domain "mcp:brew".
    #
    # @param kb [KBS::KnowledgeBase] the classify KB
    # @param decisions [AIA::Decisions]
    # @param server_tools [Hash{String => Array<String>}]
    def build_mcp_server_classify_rules(kb, decisions, server_tools)
      return unless kb

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
    #
    # @param kb [KBS::KnowledgeBase] the route KB
    # @param decisions [AIA::Decisions]
    # @param server_tools [Hash{String => Array<String>}]
    def build_mcp_server_route_rules(kb, decisions, server_tools)
      return unless kb

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
  end
end
