# frozen_string_literal: true

# lib/aia/mcp_connection_manager.rb
#
# Single owner for MCP connection state. Handles connecting to configured
# MCP servers concurrently, tracking successes/failures, and injecting
# results into robots.

require 'timeout'
require 'tty-spinner'

module AIA
  class MCPConnectionManager
    # Maximum seconds to wait for a single MCP server to connect.
    DEFAULT_TIMEOUT = 30

    attr_reader :connected_clients, :connected_tools, :failed_servers

    def initialize
      @connected_clients    = {}
      @connected_tools      = []
      @failed_servers       = []
      @server_tool_counts   = {}
      @connected            = false
      @mutex                = Mutex.new
    end

    # Connect all configured MCP servers concurrently.
    # Each server gets its own spinner line and thread.
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

      multi = TTY::Spinner::Multi.new(
        "[:spinner] Connecting MCP servers",
        format: :dots,
        output: $stderr
      )

      threads = servers.map do |server_config|
        name = server_config.is_a?(Hash) ? (server_config[:name] || server_config['name']) : server_config.to_s

        spinner = multi.register("[:spinner] #{name}")

        Thread.new(server_config, name, spinner) do |cfg, srv_name, sp|
          connect_one(cfg, srv_name, sp, logger)
        end
      end

      threads.each(&:join)

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
      AIA.config.connected_mcp_servers  = @connected_clients.keys
      AIA.config.mcp_server_tool_counts = @server_tool_counts
      AIA.config.failed_mcp_servers     = @failed_servers
      self
    end

    # Whether connect_all has been called.
    def connected?
      @connected
    end

    # Whether any tools were collected (from config servers or Ruby require).
    def any_tools?
      @connected_tools.any?
    end

    # Absorb MCP clients registered in RubyLLM::MCP (e.g., via --require loading
    # shared_tools/mcp/* files) that are not already tracked by this manager.
    # Starts any unstarted clients, extracts their tools, and merges them into
    # the connected state so inject_into will include them in the robot.
    #
    # @return [self]
    def absorb_ruby_llm_mcp_clients
      return self unless defined?(RubyLLM::MCP)

      logger = AIA::LoggerManager.mcp_logger

      RubyLLM::MCP.clients.each do |name, client|
        next if @connected_clients.key?(name)

        begin
          client.start unless client.alive?

          if client.alive?
            tools = client.tools rescue []
            @mutex.synchronize do
              @connected_clients[name]  = client
              @server_tool_counts[name] = tools.size
              @connected_tools.concat(tools)
            end
            logger.info("MCP: absorbed RubyLLM::MCP client '#{name}' (#{tools.size} tools)")
          else
            logger.warn("MCP: RubyLLM::MCP client '#{name}' not alive, skipping")
          end
        rescue StandardError => e
          logger.warn("MCP: error absorbing RubyLLM::MCP client '#{name}': #{e.message}")
        end
      end

      @connected = true unless RubyLLM::MCP.clients.empty?
      self
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

    # Connect a single MCP server, updating the spinner on completion.
    def connect_one(server_config, name, spinner, logger)
      timeout = server_timeout(server_config)
      spinner.auto_spin

      logger.info("MCP: connecting to '#{name}'...")
      Timeout.timeout(timeout) do
        client = RobotLab::MCP::Client.new(server_config)
        client.connect

        if client.connected?
          tools = client.list_tools
          built_tools = tools.map do |tool_def|
            tool_name  = tool_def[:name]
            mcp_client = client
            RobotLab::Tool.create(
              name:        tool_name,
              description: tool_def[:description],
              parameters:  tool_def[:inputSchema],
              mcp:         name
            ) { |args| mcp_client.call_tool(tool_name, args) }
          end

          @mutex.synchronize do
            @connected_clients[name]  = client
            @server_tool_counts[name] = tools.size
            @connected_tools.concat(built_tools)
          end

          logger.info("MCP: '#{name}' connected (#{tools.size} tools)")
          spinner.success("(#{tools.size} tools)")
        else
          @mutex.synchronize do
            @failed_servers << { name: name, error: "connection failed" }
          end
          logger.warn("MCP: '#{name}' failed to connect")
          spinner.error("(connection failed)")
        end
      end
    rescue Timeout::Error
      @mutex.synchronize do
        @failed_servers << { name: name, error: "timed out after #{timeout}s" }
      end
      logger.warn("MCP: '#{name}' timed out after #{timeout}s")
      spinner.error("(timed out)")
    rescue StandardError => e
      @mutex.synchronize do
        @failed_servers << { name: name, error: e.message }
      end
      logger.warn("MCP: '#{name}' error: #{e.message}")
      spinner.error("(#{e.message})")
    end

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
