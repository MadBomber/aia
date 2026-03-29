# frozen_string_literal: true

# lib/aia/mcp_discovery.rb
#
# Determines which MCP servers should be activated for a given prompt.
# Two strategies: explicit (user directive) or all configured (default).

module AIA
  class MCPDiscovery
    def initialize
    end

    # Discover relevant MCP servers for the current prompt.
    # Priority: explicit --mcp-use list > all configured servers.
    # --mcp-skip is always applied last.
    #
    # @param config the AIA configuration
    # @return [Array<Hash>] relevant MCP server configs
    def discover(config)
      return [] if config.flags&.no_mcp

      servers = select_servers(config)
      apply_skip_filter(servers, config)
    end

    private

    def select_servers(config)
      return select_by_names(config.mcp_servers || [], Array(config.mcp_use)) if Array(config.mcp_use).any?

      config.mcp_servers || []
    end

    def apply_skip_filter(servers, config)
      skip_list = Array(config.mcp_skip)
      return servers if skip_list.empty?

      servers.reject { |s| skip_list.include?(AIA::Utility.server_name(s)) }
    end

    def select_by_names(all_servers, names)
      all_servers.select { |s| names.include?(AIA::Utility.server_name(s)) }
    end
  end
end
