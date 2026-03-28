# frozen_string_literal: true

# lib/aia/mcp_utility.rb
#
# MCP-related query methods mixed into AIA::Utility via `class << self include`.
# Handles server name resolution, connection state, and banner formatting.

module AIA
  module MCPUtility
    def mcp_servers?
      effective_mcp_server_names.any?
    end

    def mcp_server_names
      connected = AIA.config&.connected_mcp_servers
      return connected unless connected.nil?
      return RubyLLM::MCP.clients.keys if defined?(RubyLLM::MCP) && RubyLLM::MCP.clients.any?
      effective_mcp_server_names
    end

    def connected_mcp_servers?
      mcp_server_names.any?
    end

    def failed_mcp_servers
      AIA.config&.failed_mcp_servers || []
    end

    def effective_mcp_server_names
      return [] if AIA.config&.flags&.no_mcp
      servers = AIA.config&.mcp_servers || []
      return [] if servers.empty?

      names     = servers.map { |s| server_name(s) }.compact
      use_list  = Array(AIA.config.mcp_use)
      skip_list = Array(AIA.config.mcp_skip)

      if use_list.any?
        names.select { |n| use_list.include?(n) }
      elsif skip_list.any?
        names.reject { |n| skip_list.include?(n) }
      else
        names
      end
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

    private

    def mcp_client_labels
      return [] if AIA.config&.flags&.no_mcp

      connected = AIA.config&.connected_mcp_servers
      unless connected.nil?
        counts = AIA.config&.mcp_server_tool_counts || {}
        return connected.map { |name|
          count = counts[name]
          count ? "#{name}(#{count})" : name
        }
      end

      return [] unless defined?(RubyLLM::MCP)
      RubyLLM::MCP.clients.filter_map do |name, client|
        count = client.tools.count rescue nil
        "#{name}(#{count})" if count
      end
    end

    def banner_mcp
      connected = mcp_client_labels
      failed    = failed_mcp_servers.map { |f| server_name(f) }
      return '(none configured)' if connected.empty? && failed.empty?
      parts = []
      parts << connected.join(', ')           unless connected.empty?
      parts << "FAILED: #{failed.join(', ')}" unless failed.empty?
      parts.join(' | ')
    end
  end
end
