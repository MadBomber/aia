# frozen_string_literal: true

# lib/aia/mcp_config_normalizer.rb
#
# Normalizes MCP server configurations from AIA format to robot_lab format,
# and filters servers based on use/skip lists and KBS activation decisions.
# Extracted from RobotFactory to give it a single focused responsibility.

module AIA
  class MCPConfigNormalizer
    class << self
      # Filter and normalize MCP server configs from AIA config.
      # Returns normalized configs ready for robot_lab.
      #
      # @param config [AIA::Config]
      # @return [Array<Hash>]
      def filter_servers(config)
        return [] if config.flags.no_mcp

        servers = config.mcp_servers || []
        return [] if servers.empty?

        use_list  = Array(config.mcp_use)
        skip_list = Array(config.mcp_skip)

        if !use_list.empty?
          servers = servers.select { |s| Utility.server_name(s) }
                           .select { |s| use_list.include?(Utility.server_name(s)) }
        elsif !skip_list.empty?
          servers = servers.reject { |s| skip_list.include?(Utility.server_name(s)) }
        end

        kbs_active = AIA.turn_state&.active_mcp_servers
        if kbs_active && !kbs_active.empty? && use_list.empty? && skip_list.empty?
          servers = servers.select { |s| kbs_active.include?(Utility.server_name(s)) }
        end

        servers.map { |s| normalize(s) }
      end

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
