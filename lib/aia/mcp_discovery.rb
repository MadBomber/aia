# frozen_string_literal: true

# lib/aia/mcp_discovery.rb
#
# Determines which MCP servers should be activated for a given prompt.
# Three strategies: explicit (user directive), rule-based (KBS), or all (default).

module AIA
  class MCPDiscovery
    def initialize(rule_router)
      @rule_router = rule_router
    end

    # Discover relevant MCP servers for the current prompt.
    #
    # @param config the AIA configuration
    # @param input [String, nil] the user's input text
    # @return [Array<Hash>] relevant MCP server configs
    def discover(config, input = nil)
      return [] if config.flags&.no_mcp
      return explicit_servers(config) if config.mcp_use

      # Rule-based discovery via KBS
      decisions = @rule_router.decisions
      activated = decisions.mcp_activations.map { |a| a[:server] }

      if activated.any?
        filter_servers(config.mcp_servers, activated)
      else
        # Fall back to all configured servers (current behavior)
        config.mcp_servers || []
      end
    end

    private

    def explicit_servers(config)
      use_list = Array(config.mcp_use)
      filter_servers(config.mcp_servers || [], use_list)
    end

    def filter_servers(all_servers, names)
      all_servers.select do |s|
        name = s[:name] || s["name"]
        names.include?(name)
      end
    end
  end
end
