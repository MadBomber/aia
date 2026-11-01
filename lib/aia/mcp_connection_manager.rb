# frozen_string_literal: true

# lib/aia/mcp_connection_manager.rb
#
# Single owner for MCP connection state. Builds one RubyLLM::MCP server per
# configured MCP server (via RobotLab::MCP.build), connects them concurrently
# at startup, and hands the live server instances to every robot aia builds.
#
# Robots share these instances: robot_lab's per-robot MCP::Registry returns
# an already-registered instance unchanged, so each server process (or HTTP
# session) is started once per aia process no matter how many robots use it.
# Servers that fail to connect are left out, so robots never retry them on
# every turn.

require 'timeout'
require 'tty-spinner'

module AIA
  # :reek:TooManyMethods -- one small helper per connection-lifecycle concern (connect, record outcomes, query, close)
  class MCPConnectionManager
    # Maximum seconds to wait for a single MCP server to connect.
    DEFAULT_TIMEOUT = 30

    attr_reader :failed_servers

    class << self
      # Select the servers for this session (MCPDiscovery: --mcp-use,
      # --mcp-skip, --no-mcp), connect them, and publish the results to
      # AIA.config and AIA.mcp_manager.
      #
      # @param config [AIA::Config]
      # @return [MCPConnectionManager]
      def start(config)
        manager = new
        unless config.flags&.no_mcp
          discovered = MCPDiscovery.new.discover(config)
          warn_unknown_mcp_use_names(config, discovered)
          manager.connect_all(discovered)
          manager.update_config if manager.connected?
        end
        AIA.mcp_manager = manager
      end

      # Warn when --mcp-use names don't match any configured server.
      # Helps users catch typos before a silent empty-tools session.
      def warn_unknown_mcp_use_names(config, discovered)
        requested = Array(config.mcp_use)
        return if requested.empty?

        missing = requested - discovered.map { AIA::Utility.server_name(it) }
        return if missing.empty?

        available = Array(config.mcp_servers).map { AIA::Utility.server_name(it) }
        $stderr.puts "WARNING: --mcp-use specified server(s) not found in config: #{missing.join(', ')}"
        $stderr.puts "         Available servers: #{available.join(', ')}" if available.any?
      end
    end

    def initialize
      @servers        = {} # name => RubyLLM::MCP (connected)
      @server_tools   = {} # name => Array<RubyLLM::MCP::Tool>
      @failed_servers = []
      @connected      = false
      @mutex          = Mutex.new
    end

    # Connect all configured MCP servers concurrently.
    # Each server gets its own spinner line and thread.
    #
    # @param configs [Array<Hash>] MCP server configurations
    # @return [self]
    # :reek:TooManyStatements -- connection ceremony: spinner setup, thread launch, global timeout guard, summary logging
    def connect_all(configs)
      return self unless configs.is_a?(Array) && configs.any?

      reset_connection_state
      logger.info("MCP initialization: connecting #{configs.size} server(s): #{configs.map { config_name(it) }.join(', ')}")

      multi   = TTY::Spinner::Multi.new("[:spinner] Connecting MCP servers", format: :dots, output: $stderr)
      threads = launch_server_threads(configs, multi)

      # The global cap must never be smaller than the slowest single server's
      # timeout, or concurrent connections get killed before they can finish.
      global_limit = [global_connection_timeout, *configs.map { server_timeout(it) }].max
      Timeout.timeout(global_limit) { threads.each(&:join) }

      @connected = true
      logger.info("MCP initialization complete: #{@servers.size} connected, #{@failed_servers.size} failed")
      self
    rescue Timeout::Error
      handle_global_timeout(configs, global_limit)
    end

    # The connected servers, in connection order.
    #
    # @return [Array<RubyLLM::MCP>]
    def servers
      @mutex.synchronize { @servers.values }
    end

    # The connected servers named by +configs+ (Hashes, names, or servers),
    # skipping any that are not connected.
    #
    # @param configs [Array<Hash, String, RubyLLM::MCP>]
    # @return [Array<RubyLLM::MCP>]
    def servers_for(configs)
      @mutex.synchronize { Array(configs).filter_map { @servers[config_name(it)] } }
    end

    # Find a connected server by name.
    #
    # @param name [String]
    # @return [RubyLLM::MCP, nil]
    def server(name)
      @mutex.synchronize { @servers[name.to_s] }
    end

    # Every connected server's tools.
    #
    # @return [Array<RubyLLM::MCP::Tool>]
    def connected_tools
      @mutex.synchronize { @server_tools.values.flatten }
    end

    # Tools grouped by the name of the server that offers them.
    #
    # @return [Hash{String => Array<RubyLLM::MCP::Tool>}]
    def tools_by_server
      @mutex.synchronize { @server_tools.transform_values(&:dup) }
    end

    # Update AIA config with connection results.
    #
    # @return [self]
    def update_config
      connected_keys, tool_counts, failed = @mutex.synchronize do
        [@servers.keys, @server_tools.transform_values(&:size), @failed_servers.dup]
      end
      cfg = AIA.config
      cfg.connected_mcp_servers  = connected_keys
      cfg.mcp_server_tool_counts = tool_counts
      cfg.failed_mcp_servers     = failed
      self
    end

    # Whether connect_all has run to completion (or hit the global timeout).
    def connected?
      @connected
    end

    # Whether any MCP tools were collected.
    def any_tools?
      @mutex.synchronize { @server_tools.values.any?(&:any?) }
    end

    # Connected server names.
    #
    # @return [Array<String>]
    def connected_server_names
      @mutex.synchronize { @servers.keys }
    end

    # Failed server names.
    #
    # @return [Array<String>]
    def failed_server_names
      @mutex.synchronize { @failed_servers.map { it[:name] } }
    end

    # Close all connected servers (stopping stdio processes) and reset state.
    def close_all
      servers.each { close_quietly(it) }
      @mutex.synchronize do
        @servers      = {}
        @server_tools = {}
        @connected    = false
      end
    end

    private

    def reset_connection_state
      @servers        = {}
      @server_tools   = {}
      @failed_servers = []
    end

    def config_name(spec)
      AIA::Utility.server_name(spec).to_s
    end

    # The shared MCP log (memoized by LoggerManager, safe across the connect threads).
    def logger
      AIA::LoggerManager.mcp_logger
    end

    def launch_server_threads(configs, multi)
      configs.map do |server_config|
        name    = config_name(server_config)
        spinner = multi.register("[:spinner] #{name}")
        Thread.new(server_config, name, spinner) { |cfg, srv_name, sp| connect_one(cfg, srv_name, sp) }
      end
    end

    def handle_global_timeout(configs, global_limit)
      logger.warn("MCP: Global connection timeout (#{global_limit}s) reached")

      @mutex.synchronize do
        settled    = @servers.keys + @failed_servers.map { it[:name] }
        stragglers = configs.map { config_name(it) } - settled
        @failed_servers.concat(stragglers.map { { name: it, error: "global connection timeout (#{global_limit}s)" } })
        @connected = true
      end
      self
    end

    # Read global MCP connection timeout from config.
    # Falls back to 120s if config is unavailable.
    def global_connection_timeout
      AIA.config&.concurrency&.mcp_timeout.to_i.then { it.positive? ? it : 120 }
    rescue StandardError
      120
    end

    # Build and connect a single MCP server, updating the spinner on completion.
    # Listing the server's tools is what makes RubyLLM::MCP connect.
    # :reek:TooManyStatements -- one connect attempt with per-outcome reporting (success, timeout, error)
    def connect_one(server_config, name, spinner)
      timeout = server_timeout(server_config)
      spinner.auto_spin
      logger.info("MCP: connecting to '#{name}'...")

      server = RobotLab::MCP.build(MCPConfigNormalizer.normalize(server_config))
      tools  = Timeout.timeout(timeout) { server.tools }
      record_connected(name, server, tools, spinner)
    rescue Timeout::Error
      close_quietly(server)
      report_failure(name, "timed out after #{timeout}s", "(timed out)", spinner)
    rescue StandardError => e
      close_quietly(server)
      report_failure(name, e.message, "(#{e.message})", spinner)
    end

    # Record a connected server. robot_lab refuses to offer two tools with one
    # name, so a server whose tool names clash with an already-connected
    # server's is recorded as failed with the fix (prefix:) spelled out.
    def record_connected(name, server, tools, spinner)
      clash = @mutex.synchronize do
        found = tool_name_clash(tools)
        unless found
          @servers[name]      = server
          @server_tools[name] = tools
        end
        found
      end
      return report_clash(name, server, clash, spinner) if clash

      logger.info("MCP: '#{name}' connected (#{tools.size} tools)")
      spinner.success("(#{tools.size} tools)")
    end

    # MUST be called inside @mutex.synchronize.
    # @return [Array(String, String), nil] [tool name, owning server] of the first clash
    def tool_name_clash(tools)
      names = tools.map { it.name.to_s }
      @server_tools.each do |owner, owned|
        dup = owned.map { it.name.to_s }.find { names.include?(it) }
        return [dup, owner] if dup
      end
      nil
    end

    def report_clash(name, server, clash, spinner)
      close_quietly(server)
      tool, owner = clash
      report_failure(name, "tool '#{tool}' is also offered by '#{owner}'; give one server a prefix:",
                     "(duplicate tool '#{tool}')", spinner)
    end

    def report_failure(name, error, spinner_note, spinner)
      @mutex.synchronize { @failed_servers << { name: name, error: error } }
      logger.warn("MCP: '#{name}' error: #{error}")
      spinner.error(spinner_note)
    end

    # Best-effort close; a server that never connected may raise.
    def close_quietly(server)
      server&.close
    rescue StandardError
      nil # nothing to clean up on a server that never started
    end

    # Extract timeout in seconds from server config.
    # Config values >= 1000 are treated as milliseconds.
    def server_timeout(server_config)
      raw = server_config.is_a?(Hash) ? (server_config[:timeout] || server_config['timeout']) : nil
      return DEFAULT_TIMEOUT if raw.nil?

      seconds = raw.to_f
      seconds /= 1000.0 if seconds >= 1000 # values >= 1000 are milliseconds
      # Honor the configured per-server timeout. DEFAULT_TIMEOUT is only the
      # fallback when no timeout is set (handled above) — it must NOT cap a
      # larger configured value, or slow-starting servers (npx/uvx cold starts)
      # get dropped and their tools never reach the robot or the tool filter.
      seconds.positive? ? seconds : DEFAULT_TIMEOUT
    end
  end
end
