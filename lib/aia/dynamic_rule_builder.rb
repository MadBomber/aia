# frozen_string_literal: true

# lib/aia/dynamic_rule_builder.rb

require 'fileutils'
require_relative 'keyword_extractor'
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

    # Ruby source filename for persisted keyword rules (--save / --load).
    PERSIST_FILENAME = "kbs_keyword_rules.rb"

    module_function

    # Orchestrate the full dynamic rule registration flow.
    #
    # @param knowledge_bases [Hash{Symbol => KBS::KnowledgeBase}]
    # @param decisions [AIA::Decisions]
    # @param fact_asserter [AIA::FactAsserter]
    # @param tools [Array] loaded tool classes
    # @param db_dir [String, nil] directory for persist file (e.g. ~/.config/aia)
    # @param load_db [Boolean] load persisted keyword data if available
    # @param save_db [Boolean] persist keyword data after computing
    # @return [Hash] { domain_tools: Hash, server_tools: Hash }
    def register(knowledge_bases, decisions, fact_asserter, tools,
                 db_dir: nil, load_db: false, save_db: false)
      domain_tools = map_tools_to_domains(tools, fact_asserter)
      server_tools = map_tools_to_mcp_servers(tools, fact_asserter)

      build_dynamic_classify_rules(knowledge_bases[:classify], decisions, domain_tools)
      build_dynamic_tool_rules(knowledge_bases[:route], decisions, domain_tools)
      build_server_scoped_domain_rules(knowledge_bases[:route], decisions, domain_tools, server_tools)
      build_mcp_server_classify_rules(knowledge_bases[:classify], decisions, server_tools)
      build_mcp_server_route_rules(knowledge_bases[:route], decisions, server_tools)
      build_keyword_route_rules(knowledge_bases[:route], decisions, tools, fact_asserter,
        db_dir: db_dir, load_db: load_db, save_db: save_db)

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
        server = tool_class.respond_to?(:mcp) ? tool_class.mcp&.to_s : nil
        text = "#{name} #{desc}"

        TOOL_DOMAIN_PATTERNS.each do |domain, pattern|
          domain_tools[domain] << { name: name, server: server } if text.match?(pattern)
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

    # Build route KB rules that activate LOCAL tools when their domain
    # matches the classified input domain. MCP tools are NOT activated
    # by domain alone — they require their server name to be classified
    # (via build_mcp_server_route_rules or build_server_scoped_domain_rules).
    #
    # @param kb [KBS::KnowledgeBase] the route KB
    # @param decisions [AIA::Decisions]
    # @param domain_tools [Hash{String => Array<Hash>}] domain => [{name:, server:}]
    def build_dynamic_tool_rules(kb, decisions, domain_tools)
      return unless kb

      domain_tools.each do |domain, tool_entries|
        local_entries = tool_entries.select { |e| e[:server].nil? }
        next if local_entries.empty?

        names = local_entries.map { |e| e[:name] }.freeze

        kb.rule "activate_#{domain}_local_tools" do
          on :classification_decision, domain: domain
          on :tool, name: satisfies { |n| names.include?(n.to_s) }
          perform do |facts|
            decisions.add(:tool_activate,
              tool:   facts[1][:name],
              server: nil,
              reason: "#{domain} domain (local)")
          end
        end
      end
    end

    # Build higher-specificity rules that fire when BOTH a generic domain
    # AND a specific MCP server are classified. Activates only the
    # intersection: tools from that server in that domain.
    #
    # @param kb [KBS::KnowledgeBase] the route KB
    # @param decisions [AIA::Decisions]
    # @param domain_tools [Hash{String => Array<Hash>}] domain => [{name:, server:}]
    # @param server_tools [Hash{String => Array<String>}] server_name => tool names
    def build_server_scoped_domain_rules(kb, decisions, domain_tools, server_tools)
      return unless kb

      server_tools.each_key do |server_name|
        domain_tools.each do |domain, tool_entries|
          server_domain_tools = tool_entries.select { |e| e[:server] == server_name }
          next if server_domain_tools.empty?

          names = server_domain_tools.map { |e| e[:name] }.freeze

          kb.rule "activate_#{domain}_#{server_name}_scoped" do
            on :classification_decision, domain: domain
            on :classification_decision, domain: "mcp:#{server_name}"
            on :tool, name: satisfies { |n| names.include?(n.to_s) }
            perform do |facts|
              decisions.add(:tool_activate,
                tool:   facts[2][:name],
                server: server_name,
                reason: "#{domain} domain + #{server_name} server")
            end
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

    # Generate one KBS rule per tool in the :route KB.
    # The rule fires when the prompt's keyword Set overlaps with
    # the tool's TF-IDF-distinctive keyword Set.
    #
    # When load_db is true and a persisted .rb file exists, evaluates
    # that source directly on the KB instead of recomputing TF-IDF.
    # When save_db is true, writes a Ruby source file after computing.
    #
    # @param kb [KBS::KnowledgeBase] the route KB
    # @param decisions [AIA::Decisions]
    # @param tools [Array] loaded tool objects
    # @param fact_asserter [AIA::FactAsserter]
    # @param db_dir [String, nil] directory for persist file
    # @param load_db [Boolean] load persisted source if available
    # @param save_db [Boolean] write Ruby source to disk after computing
    def build_keyword_route_rules(kb, decisions, tools, fact_asserter,
                                   db_dir: nil, load_db: false, save_db: false)
      return unless kb
      return if tools.empty?

      rules_dir = db_dir ? File.join(db_dir, 'rules') : nil

      if load_db
        source = load_keyword_source(rules_dir)
        if source
          kb.instance_eval(source)
          return
        end
      end

      keywords_by_tool = compute_keyword_data(tools, fact_asserter)
      save_keyword_source(rules_dir, tools, fact_asserter, keywords_by_tool) if save_db
      build_rules_from_keyword_data(kb, decisions, tools, fact_asserter, keywords_by_tool)
    end

    # Compute keyword data fresh using TF-IDF.
    def compute_keyword_data(tools, fact_asserter)
      corpus = tools.each_with_object({}) do |tool, h|
        name = fact_asserter.tool_name(tool)
        desc = fact_asserter.tool_description(tool)
        h[name] = "#{name.tr('_', ' ')} #{desc}"
      end
      KeywordExtractor.distinctive_keywords(corpus)
    end

    # Instantiate KBS rules from a pre-built keywords_by_tool hash.
    def build_rules_from_keyword_data(kb, decisions, tools, fact_asserter, keywords_by_tool)
      tools.each do |tool|
        name   = fact_asserter.tool_name(tool)
        server = tool.respond_to?(:mcp) ? tool.mcp&.to_s : nil
        kws    = keywords_by_tool[name]
        next if kws.nil? || kws.empty?

        # Capture in locals — KBS blocks are closures evaluated later
        captured_name   = name
        captured_server = server
        captured_kws    = kws
        rule_key        = "keyword_route_#{name.gsub(/\W/, '_')}"

        kb.rule rule_key do
          on :turn_input, keywords: satisfies { |pk| (pk & captured_kws).size >= 1 }
          perform do |facts|
            matched = (facts[0][:keywords] & captured_kws).to_a
            decisions.add(:tool_activate,
              tool:   captured_name,
              server: captured_server,
              reason: "keyword overlap(#{matched.size}): #{matched.first(3).join(', ')}")
          end
        end
      end
    end

    # Load persisted Ruby source from the rules directory.
    # Returns file content as String on success, nil on failure or missing file.
    def load_keyword_source(rules_dir)
      return nil unless rules_dir

      path = File.join(rules_dir, PERSIST_FILENAME)
      return nil unless File.exist?(path)

      source = File.read(path)
      $stderr.puts "[KBS] Loaded persisted keyword rules from #{path}."
      source
    rescue StandardError => e
      $stderr.puts "[KBS] Failed to load persisted keyword rules: #{e.message}"
      nil
    end

    # Save keyword rules as Ruby source that can be instance_eval'd on a route KB.
    # Written to the rules directory (~/.config/aia/rules/).
    # Uses unique variable names per tool to avoid closure capture aliasing.
    def save_keyword_source(rules_dir, tools, fact_asserter, keywords_by_tool)
      return unless rules_dir && !keywords_by_tool.empty?

      lines = [
        "# frozen_string_literal: true",
        "# kbs_keyword_rules.rb — generated by AIA::DynamicRuleBuilder",
        "# Evaluated via kb.instance_eval to restore keyword-overlap routing rules.",
        "",
        "require 'set'",
        ""
      ]

      tools.each do |tool|
        name      = fact_asserter.tool_name(tool)
        server    = tool.respond_to?(:mcp) ? tool.mcp&.to_s : nil
        kws       = keywords_by_tool[name]
        next if kws.nil? || kws.empty?

        var_suffix     = name.gsub(/\W/, '_')
        kws_var        = "_kws_#{var_suffix}"
        rule_key       = "keyword_route_#{var_suffix}"
        server_literal = server ? server.inspect : "nil"
        kws_literal    = "Set.new(#{kws.to_a.sort.inspect})"

        lines << "#{kws_var} = #{kws_literal}"
        lines << "rule #{rule_key.inspect} do"
        lines << "  on :turn_input, keywords: satisfies { |pk| (pk & #{kws_var}).size >= 1 }"
        lines << "  perform do |facts|"
        lines << "    matched = (facts[0][:keywords] & #{kws_var}).to_a"
        lines << "    AIA.decisions.add(:tool_activate,"
        lines << "      tool:   #{name.inspect},"
        lines << "      server: #{server_literal},"
        lines << "      reason: \"keyword overlap(\#{matched.size}): \#{matched.first(3).join(', ')}\")"
        lines << "  end"
        lines << "end"
        lines << ""
      end

      FileUtils.mkdir_p(rules_dir)
      path = File.join(rules_dir, PERSIST_FILENAME)
      File.write(path, lines.join("\n"))
      $stderr.puts "[KBS] Saved keyword rules to #{path}."
    rescue StandardError => e
      $stderr.puts "[KBS] Failed to save keyword rules: #{e.message}"
    end
  end
end
