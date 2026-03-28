# frozen_string_literal: true

# lib/aia/mcp_config_normalizer.rb
#
# Normalizes a single MCP server config from AIA flat format to the nested
# transport format expected by robot_lab. Server selection/filtering is
# the responsibility of MCPDiscovery — this class only transforms shape.

module AIA
  class MCPConfigNormalizer
    class << self
      # Normalize a single MCP server config to robot_lab's nested transport format.
      #
      # @param server [Hash]
      # @return [Hash]
      def normalize(server)
        server = server.is_a?(Hash) ? server.transform_keys(&:to_sym) : server.to_h.transform_keys(&:to_sym)

        # Already in robot_lab format — pass through
        return server if server[:transport]

        # Legacy flat format: wrap command/args/env into transport
        name      = server[:name]
        transport = { type: server[:type] || 'stdio' }
        transport[:command] = server[:command] if server[:command]
        transport[:args]    = Array(server[:args]) if server[:args]
        transport[:env]     = server[:env] if server[:env]

        result = { name: name, transport: transport }
        result[:timeout] = server[:timeout] if server[:timeout]
        result
      end
    end
  end
end
