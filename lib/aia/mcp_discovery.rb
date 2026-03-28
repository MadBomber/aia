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
    # Priority: explicit --mcp-use list > KBS activations > all configured servers.
    # --mcp-skip is always applied last.
    #
    # @param config the AIA configuration
    # @param input [String, nil] the user's input text (unused; reserved for future embedding)
    # @return [Array<Hash>] relevant MCP server configs (raw, not yet normalized)
    def discover(config, input = nil)
      return [] if config.flags&.no_mcp

      servers = select_servers(config)
      apply_skip_filter(servers, config)
    end

    private

    # Choose the server subset before skip filtering.
    def select_servers(config)
      # --mcp-use takes explicit precedence (only when list is non-empty)
      return select_by_names(config.mcp_servers || [], Array(config.mcp_use)) if Array(config.mcp_use).any?

      # KBS rule-based activation (populated by routing KB rules)
      activated = @rule_router.decisions.mcp_activations.map { |a| a[:server] }
      if activated.any?
        select_by_names(config.mcp_servers || [], activated)
      else
        # Default: all configured servers
        config.mcp_servers || []
      end
    end

    # Remove servers whose names appear in the --mcp-skip list.
    def apply_skip_filter(servers, config)
      skip_list = Array(config.mcp_skip)
      return servers if skip_list.empty?

      servers.reject { |s| skip_list.include?(AIA::Utility.server_name(s)) }
    end

    # Select servers whose name is in +names+.
    def select_by_names(all_servers, names)
      all_servers.select { |s| names.include?(AIA::Utility.server_name(s)) }
    end
  end
end
