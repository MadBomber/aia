# frozen_string_literal: true

# lib/aia/mcp_discovery.rb
#
# Determines which MCP servers should be activated for a given prompt.
# Two strategies: explicit (user directive) or all configured (default).

module AIA
  class MCPDiscovery
    def initialize; end

    # The servers --mcp-use keeps (all of them when it is empty), minus
    # those --mcp-skip names. Shared by sessions, --mcp-list and the banner.
    #
    # @param servers [Array<Hash>] configured servers
    # @param use [Array<String>] --mcp-use names
    # @param skip [Array<String>] --mcp-skip names
    # @return [Array<Hash>]
    def self.select(servers, use: [], skip: [])
      use  = Array(use)
      skip = Array(skip)
      kept = use.empty? ? Array(servers) : Array(servers).select { use.include?(AIA::Utility.server_name(it)) }
      kept.reject { skip.include?(AIA::Utility.server_name(it)) }
    end

    # Discover relevant MCP servers for the current prompt.
    # Priority: explicit --mcp-use list > all configured servers.
    # --mcp-skip is always applied last. Entries that name a RubyLLM::MCP
    # subclass are resolved to the class (see #resolve_entries).
    #
    # @param config the AIA configuration
    # @return [Array<Hash, Class<RubyLLM::MCP>>] relevant MCP server configs
    def discover(config)
      return [] if config.flags&.no_mcp

      selected = self.class.select(config.mcp_servers || [], use: config.mcp_use, skip: config.mcp_skip)
      resolve_entries(selected)
    end

    # Turn constant-name entries ("SharedTools::MCP::Memory") into their
    # RubyLLM::MCP subclass, loaded by --require before MCP servers connect.
    # An entry that names no such class, or whose class reports itself
    # unavailable via +available?+ (e.g. a missing API key), is skipped
    # with a one-line note. Hash entries pass through unchanged.
    #
    # @param entries [Array<Hash, String, Class>]
    # @return [Array<Hash, Class<RubyLLM::MCP>>]
    def resolve_entries(entries)
      entries.filter_map do |entry|
        klass = AIA::Utility.mcp_class_name?(entry) ? RobotLab::MCP.resolve(entry) : entry
        next klass unless klass.is_a?(Class) && klass.respond_to?(:available?) && !klass.available?

        note_skipped(AIA::Utility.server_name(klass), unavailable_reason(klass))
      rescue RobotLab::MCPError => e
        note_skipped(entry, e.message)
      end
    end

    private

    def unavailable_reason(klass)
      missing = klass.respond_to?(:missing_envars) ? Array(klass.missing_envars) : []
      missing.empty? ? "not available" : "missing #{missing.join(', ')}"
    end

    # Report a skipped server; returns nil so filter_map drops the entry.
    def note_skipped(name, reason)
      $stderr.puts "Info: MCP server '#{name}' skipped (#{reason})"
      nil
    end
  end
end
