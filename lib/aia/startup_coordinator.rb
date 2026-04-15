# frozen_string_literal: true

# lib/aia/startup_coordinator.rb
#
# Handles all session startup tasks: MCP connection, tool loading,
# filter initialization, task coordination, and bus attachment.
# Extracted from Session to give Session a single responsibility.

require "fileutils"

module AIA
  class StartupCoordinator
    attr_reader :filters, :mcp_manager

    def initialize(robot:, ui_presenter:)
      @robot       = robot
      @ui          = ui_presenter
      @filters     = {}
      @mcp_manager = nil
    end

    # Run all startup coordination tasks.
    #
    # @param config [AIA::Config]
    def run(config)
      connect_mcp_servers(config)
      tools    = all_available_tools(config)
      @filters = ToolFilterRegistry.build_from_config(config, tools)
      initialize_task_coordinator
      attach_bus_if_network
    end

    private

    # Connect ALL configured MCP servers eagerly at startup, then absorb any
    # MCP clients registered via --require (e.g., shared_tools/mcp/* files).
    # Uses MCPDiscovery to determine which servers to connect (respects
    # --mcp-use, --mcp-skip, and KBS mcp_activate decisions), then normalizes
    # each server config via MCPConfigNormalizer before handing off to
    # MCPConnectionManager.
    def connect_mcp_servers(config)
      return if config.flags.no_mcp

      discovered = MCPDiscovery.new.discover(config)
      validate_mcp_use_names(config, discovered) if Array(config.mcp_use).any?

      servers = if @robot.respond_to?(:mcp_config) && @robot.mcp_config.is_a?(Array)
                  @robot.mcp_config
                else
                  discovered.map { |s| MCPConfigNormalizer.normalize(s) }
                end

      @mcp_manager = MCPConnectionManager.new
      @mcp_manager.connect_all(servers) if servers.is_a?(Array) && servers.any?
      @mcp_manager.absorb_ruby_llm_mcp_clients
      return unless @mcp_manager.connected?

      @mcp_manager.update_config
      @mcp_manager.inject_into(@robot) if @mcp_manager.any_tools?
    end

    # Initialize TaskCoordinator, auto-creating the TrakFlow project if needed.
    def initialize_task_coordinator
      ensure_trakflow_initialized unless TrakFlow.initialized?

      AIA.task_coordinator = TaskCoordinator.new
    rescue StandardError
      # TrakFlow coordination is best-effort
    end

    # Bootstrap a TrakFlow project so the task board is always available.
    # Uses the default database path (~/.config/trak_flow/tf.db).
    def ensure_trakflow_initialized
      trakflow_dir = TrakFlow.trak_flow_dir
      FileUtils.mkdir_p(trakflow_dir)

      db = TrakFlow::Storage::Database.new
      db.connect

      TrakFlow.reset_root!
    end

    # Attach a shared TypedBus to multi-model networks.
    def attach_bus_if_network
      return unless @robot.is_a?(RobotLab::Network)

      RobotFactory.attach_bus(@robot)
    rescue StandardError
      # Bus attachment is best-effort
    end

    # Warn when --mcp-use names don't match any configured server.
    # Helps users catch typos before a silent empty-tools session.
    def validate_mcp_use_names(config, discovered_servers)
      requested  = Array(config.mcp_use)
      available  = Array(config.mcp_servers).map { |s| AIA::Utility.server_name(s) }
      found      = discovered_servers.map { |s| AIA::Utility.server_name(s) }
      missing    = requested - found

      return if missing.empty?

      warn "WARNING: --mcp-use specified server(s) not found in config: #{missing.join(', ')}"
      warn "         Available servers: #{available.join(', ')}" if available.any?
    end

    # Collect all tools available to the robot: local + MCP.
    def all_available_tools(config)
      local = Array(config.loaded_tools)
      mcp   = collect_mcp_tools
      local + mcp
    end

    # Retrieve MCP tools from all connected MCP clients.
    def collect_mcp_tools
      defined?(RubyLLM::MCP) ? RubyLLM::MCP.clients.values.flat_map(&:tools) : []
    end
  end
end
