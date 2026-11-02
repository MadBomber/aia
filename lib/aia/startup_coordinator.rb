# frozen_string_literal: true

# lib/aia/startup_coordinator.rb
#
# Handles the session startup tasks that need the built robot: tool loading,
# filter initialization, task coordination, and bus attachment. MCP servers
# are connected before the robot is built (MCPConnectionManager.start) so
# every robot is handed the live servers. Extracted from Session to give
# Session a single responsibility.

require "fileutils"
require "tty-spinner"

module AIA
  class StartupCoordinator
    attr_reader :filters, :mcp_manager
    attr_writer :robot

    def initialize(robot:, ui_presenter:, mcp_manager: nil)
      @robot       = robot
      @ui          = ui_presenter
      @filters     = {}
      @mcp_manager = mcp_manager
    end

    # Run all startup coordination tasks.
    #
    # @param config [AIA::Config]
    def run(config)
      tools = all_available_tools(config)

      spinner = TTY::Spinner.new("  [:spinner] Initializing tool filters...", format: :dots)
      spinner.auto_spin
      @filters = ToolFilterRegistry.build_from_config(config, tools)
      spinner.success

      attach_bus_if_network
    end

    # Start the TrakFlow task board. Call this before the robot is built: the
    # task-board tools (DelegateToForemanTool) only offer themselves once it
    # is running, and the robot collects its tools when it is built.
    def prepare_task_board
      initialize_task_coordinator if trakflow_available?
    end

    private

    # Initialize TaskCoordinator, auto-creating the TrakFlow project if needed.
    def initialize_task_coordinator
      require_relative 'task_coordinator'
      require_relative 'trakflow_bridge'
      require_relative 'tools/task_board_tool'
      require_relative 'tools/delegate_to_foreman_tool'

      ensure_trakflow_initialized unless TrakFlow.initialized?

      AIA.task_coordinator = TaskCoordinator.new
    rescue StandardError => e
      AIA.debug_warn("TaskCoordinator initialization failed (non-fatal): #{e.message}", exc: e)
    end

    # Return true if the trak_flow gem is available; false if it cannot be loaded.
    def trakflow_available?
      defined?(TrakFlow) || begin
        require 'trak_flow'
        true
      rescue LoadError
        false
      end
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
      return unless @robot.network?

      RobotFactory.attach_bus(@robot)
    rescue StandardError => e
      AIA.debug_warn("Bus attachment failed (non-fatal): #{e.message}", exc: e)
    end

    # Collect all tools available to the robot: local + MCP.
    def all_available_tools(config)
      local = Array(config.loaded_tools)
      mcp   = collect_mcp_tools
      local + mcp
    end

    # MCP tools (RubyLLM::MCP::Tool) from the connection manager — the
    # servers every robot is built with.
    def collect_mcp_tools
      return [] unless @mcp_manager

      @mcp_manager.connected_tools
    end
  end
end
