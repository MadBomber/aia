# frozen_string_literal: true

# lib/aia/mcp_config_normalizer.rb
#
# Normalizes a single MCP server config from AIA flat format to the nested
# transport format expected by robot_lab (RobotLab::MCP.build). Server
# selection/filtering is the responsibility of MCPDiscovery — this class
# only transforms shape.

module AIA
  class MCPConfigNormalizer
    # Flat keys that describe how to reach the server; folded into :transport.
    TRANSPORT_KEYS = %i[type command args env url headers bearer_token oauth cwd directory].freeze

    class << self
      # Normalize a single MCP server config to robot_lab's nested transport format.
      # Settings robot_lab understands (timeout, prefix, only, except,
      # requires_approval, description, ...) are carried through unchanged.
      #
      # A RubyLLM::MCP subclass or instance, or the constant name of one,
      # already describes its own transport and is returned unchanged
      # (RobotLab::MCP.build resolves the name).
      #
      # @param server [Hash, Class<RubyLLM::MCP>, RubyLLM::MCP, String]
      # @return [Hash, Class<RubyLLM::MCP>, RubyLLM::MCP, String]
      def normalize(server)
        return server if mcp_object?(server) || AIA::Utility.mcp_class_name?(server)

        server = server.to_h.transform_keys(&:to_sym)

        # Already in robot_lab format — pass through
        return server if server[:transport]

        transport = server.slice(*TRANSPORT_KEYS).compact
        transport[:type] ||= server[:url] ? 'streamable-http' : 'stdio'
        transport[:args]   = Array(transport[:args]) if transport.key?(:args)

        server.except(*TRANSPORT_KEYS).merge(transport: transport)
      end

      # @param server [Object]
      # @return [Boolean] true for a RubyLLM::MCP instance or subclass
      def mcp_object?(server)
        server.is_a?(RubyLLM::MCP) || (server.is_a?(Class) && server <= RubyLLM::MCP)
      end
    end
  end
end
