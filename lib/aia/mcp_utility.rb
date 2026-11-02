# frozen_string_literal: true

# lib/aia/mcp_utility.rb
#
# Pure MCP state-query methods mixed into AIA::Utility via `class << self include`.
# No display or formatting concerns — those live in Utility directly.

module AIA
  module MCPUtility
    def mcp_servers?
      effective_mcp_server_names.any?
    end

    def mcp_server_names
      connected = AIA.config&.connected_mcp_servers
      return connected unless connected.nil?
      effective_mcp_server_names
    end

    def connected_mcp_servers?
      mcp_server_names.any?
    end

    def failed_mcp_servers
      AIA.config&.failed_mcp_servers || []
    end

    def effective_mcp_server_names
      cfg = AIA.config
      return [] if cfg&.flags&.no_mcp

      servers = cfg&.mcp_servers || []
      return [] if servers.empty?

      MCPDiscovery.select(servers, use: cfg.mcp_use, skip: cfg.mcp_skip).map { server_name(it) }.compact
    end

    def server_name(s)
      if s.is_a?(Hash)
        s[:name] || s['name']
      elsif s.respond_to?(:name)
        s.name
      else
        s.to_s
      end
    end
  end
end
