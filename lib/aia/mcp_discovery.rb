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
    # --mcp-skip is always applied last.
    #
    # @param config the AIA configuration
    # @return [Array<Hash>] relevant MCP server configs
    def discover(config)
      return [] if config.flags&.no_mcp

      self.class.select(config.mcp_servers || [], use: config.mcp_use, skip: config.mcp_skip)
    end
  end
end
