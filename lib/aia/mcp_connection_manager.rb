# frozen_string_literal: true

# lib/aia/mcp_connection_manager.rb
#
# Single owner for MCP connection state. Handles connecting to configured
# MCP servers, tracking successes/failures, and injecting results into robots.

require 'timeout'

module AIA
  class MCPConnectionManager
    # Maximum seconds to wait for a single MCP server to connect.
    DEFAULT_TIMEOUT = 30

    attr_reader :connected_clients, :connected_tools, :failed_servers

    def initialize
      @connected_clients = {}
      @connected_tools   = []
      @failed_servers    = []
      @connected         = false
    end

    # Connect all configured MCP servers eagerly.
    # Each server is handled independently so one failure doesn't block others.
    #
    # @param servers [Array<Hash>] MCP server configurations
    # @return [self]
    def connect_all(servers)
      return self unless servers.is_a?(Array) && servers.any?

      @connected_clients = {}
      @connected_tools   = []
      @failed_servers    = []

      logger = AIA::LoggerManager.mcp_logger
      server_names = servers.map { |s| s.is_a?(Hash) ? s[:name] : s.to_s }.compact
      logger.info("MCP initialization: connecting #{servers.size} server(s): #{server_names.join(', ')}")

      bar = TTY::ProgressBar.new(
        "Connecting MCP servers [:bar] :current/:total",
        total: servers.size,
        width: 20,
        output: $stderr
      )

      servers.each do |server_config|
        name = server_config.is_a?(Hash) ? (server_config[:name] || server_config['name']) : server_config.to_s
        timeout = server_timeout(server_config)

        begin
          logger.info("MCP: connecting to '#{name}'...")
          Timeout.timeout(timeout) do
            client = RobotLab::MCP::Client.new(server_config)
            client.connect

            if client.connected?
              @connected_clients[name] = client
              tools = client.list_tools
              tools.each do |tool_def|
                tool_name = tool_def[:name]
                mcp_client = client
                tool = RobotLab::Tool.create(
                  name:        tool_name,
                  description: tool_def[:description],
                  parameters:  tool_def[:inputSchema],
                  mcp:         name
                ) { |args| mcp_client.call_tool(tool_name, args) }
                @connected_tools << tool
              end
              logger.info("MCP: '#{name}' connected (#{tools.size} tools)")
            else
              @failed_servers << { name: name, error: "connection failed" }
              logger.warn("MCP: '#{name}' failed to connect")
            end
          end
        rescue Timeout::Error
          @failed_servers << { name: name, error: "timed out after #{timeout}s" }
          logger.warn("MCP: '#{name}' timed out after #{timeout}s")
        rescue StandardError => e
          @failed_servers << { name: name, error: e.message }
          logger.warn("MCP: '#{name}' error: #{e.message}")
        ensure
          bar.advance
        end
      end

      bar.finish
      @connected = true
      logger.info("MCP initialization complete: #{@connected_clients.size} connected, #{@failed_servers.size} failed")
      self
    end

    # Inject connected MCP clients and tools into robot(s).
    #
    # @param robot [RobotLab::Robot, RobotLab::Network] the robot or network
    # @return [self]
    def inject_into(robot)
      targets = if robot.respond_to?(:robots) && robot.robots.is_a?(Hash)
                  robot.robots.values
                else
                  [robot]
                end

      targets.each do |target|
        target.inject_mcp!(clients: @connected_clients, tools: @connected_tools)
      end

      self
    end

    # Update AIA config with connection results.
    #
    # @return [self]
    def update_config
      AIA.config.connected_mcp_servers = @connected_clients.keys
      AIA.config.failed_mcp_servers    = @failed_servers
      self
    end

    # Whether connect_all has been called.
    def connected?
      @connected
    end

    # Find an MCP client by server name.
    #
    # @param name [String] server name
    # @return [RobotLab::MCP::Client, nil]
    def client(name)
      @connected_clients[name]
    end

    # Connected server names.
    #
    # @return [Array<String>]
    def connected_server_names
      @connected_clients.keys
    end

    # Failed server names.
    #
    # @return [Array<String>]
    def failed_server_names
      @failed_servers.map { |f| f[:name] }
    end

    private

    # Extract timeout in seconds from server config.
    # Config values >= 1000 are treated as milliseconds.
    def server_timeout(server_config)
      raw = server_config.is_a?(Hash) ? server_config[:timeout] : nil
      return DEFAULT_TIMEOUT if raw.nil?

      seconds = raw.to_f
      seconds = seconds / 1000.0 if seconds >= 1000
      [seconds, DEFAULT_TIMEOUT].min
    end
  end
end
