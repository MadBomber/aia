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

    # The name a configured server is known by: a Hash's :name, a server
    # instance's #name, or for a RubyLLM::MCP subclass (or its constant name,
    # e.g. "SharedTools::MCP::GitHub") the server's default name ("github").
    # A constant name whose class is not loaded yet is returned as given.
    def server_name(s)
      case s
      when Hash   then s[:name] || s['name']
      when Class  then s.respond_to?(:default_name) ? s.default_name : s.name
      when String then mcp_class_name?(s) ? class_server_name(s) : s
      else s.respond_to?(:name) ? s.name : s.to_s
      end
    end

    # True when +value+ is shaped like a Ruby constant path ("Foo::Bar"),
    # the form an mcp_servers: entry takes to name a RubyLLM::MCP subclass.
    def mcp_class_name?(value)
      value.is_a?(String) && value.match?(/\A(::)?[A-Z]\w*(::[A-Z]\w*)*\z/)
    end

    private

    def class_server_name(constant_name)
      RobotLab::MCP.name_of(constant_name)
    rescue RobotLab::MCPError
      constant_name
    end
  end
end
