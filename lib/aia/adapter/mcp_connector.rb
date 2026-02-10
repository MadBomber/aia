# lib/aia/adapter/mcp_connector.rb
# frozen_string_literal: true

require 'simple_flow'

module AIA
  module Adapter
    class McpConnector
      # Default timeout for MCP client initialization (in milliseconds)
      # RubyLLM::MCP expects timeout in milliseconds (e.g., 8000 = 8 seconds)
      # Using a short timeout to prevent slow servers from blocking startup
      MCP_DEFAULT_TIMEOUT = 8_000  # 8 seconds (same as RubyLLM::MCP default)

      def support_mcp(tools)
        if AIA.config.flags.no_mcp
          logger.debug("MCP processing bypassed via --no-mcp flag")
          return
        end

        logger.debug("Starting MCP connection via RubyLLM::MCP.establish_connection")
        LoggerManager.configure_mcp_logger

        start_time = Time.now
        RubyLLM::MCP.establish_connection
        elapsed = Time.now - start_time

        tool_count = RubyLLM::MCP.tools.size
        tools.concat(RubyLLM::MCP.tools)

        logger.info("MCP connection established", elapsed_seconds: elapsed.round(2), tool_count: tool_count)
      rescue StandardError => e
        logger.error("Failed to connect MCP clients", error_class: e.class.name, error_message: e.message)
        logger.debug("MCP connection error backtrace", backtrace: e.backtrace&.first(5))
        warn "Warning: Failed to connect MCP clients: #{e.message}"
      end

      # =========================================================================
      # SimpleFlow-based Parallel MCP Connection
      # =========================================================================
      # Uses fiber-based concurrency to connect to all MCP servers in parallel.
      # This reduces total connection time from sum(timeouts) to max(timeouts).

      def support_mcp_with_simple_flow(tools)
        if AIA.config.flags.no_mcp
          logger.debug("MCP processing bypassed via --no-mcp flag")
          return
        end

        if AIA.config.mcp_servers.nil? || AIA.config.mcp_servers.empty?
          logger.debug("No MCP servers configured, skipping MCP setup")
          return
        end

        # Initialize tracking (kept for compatibility with Utility.robot)
        AIA.config.connected_mcp_servers = []
        AIA.config.failed_mcp_servers = []

        servers = filter_mcp_servers(AIA.config.mcp_servers)
        server_names = servers.map { |s| s[:name] || s['name'] }.compact

        logger.info("Starting parallel MCP connection", server_count: servers.size, servers: server_names)
        $stderr.puts "MCP: Connecting to #{server_names.join(', ')}..."
        $stderr.flush

        LoggerManager.configure_mcp_logger

        # Build steps array first (outside the block to preserve self reference)
        # Each step is a [name, callable] pair for parallel execution
        connector = self
        steps = servers.map do |server|
          name = (server[:name] || server['name']).to_sym
          logger.debug("Building connection step", server: name)
          [name, connector.send(:build_mcp_connection_step, server)]
        end

        # Build parallel pipeline - each server is independent (depends_on: :none)
        # All servers will connect concurrently using fiber-based async
        logger.debug("Creating SimpleFlow pipeline", step_count: steps.size)
        pipeline = SimpleFlow::Pipeline.new(concurrency: :async) do
          steps.each do |name, callable|
            step name, callable, depends_on: :none
          end
        end

        # Execute all connections in parallel
        start_time = Time.now
        initial_result = SimpleFlow::Result.new({ tools: [] })
        final_result = pipeline.call_parallel(initial_result)
        elapsed = Time.now - start_time

        logger.info("Parallel MCP connection completed", elapsed_seconds: elapsed.round(2))

        # Extract results and populate config arrays for compatibility
        extract_mcp_results(final_result, tools)
      end

      def filter_mcp_servers(servers)
        use_list = Array(AIA.config.mcp_use)
        skip_list = Array(AIA.config.mcp_skip)

        if !use_list.empty?
          servers = servers.select do |server|
            name = server[:name] || server['name']
            use_list.include?(name)
          end
          logger.info("MCP servers filtered by --mcp-use", use: use_list, remaining: servers.size)
        elsif !skip_list.empty?
          servers = servers.reject do |server|
            name = server[:name] || server['name']
            skip_list.include?(name)
          end
          logger.info("MCP servers filtered by --mcp-skip", skip: skip_list, remaining: servers.size)
        end

        servers
      end

      private

      def logger
        @logger ||= LoggerManager.aia_logger
      end

      def build_mcp_connection_step(server)
        # Capture logger in closure for use within the lambda
        log = logger

        ->(result) {
          name = server[:name] || server['name']
          start_time = Time.now

          begin
            log.debug("Registering MCP client", server: name)

            # Register client with RubyLLM::MCP
            client = register_single_mcp_client(server)

            log.debug("Starting client connection", server: name)

            # Start and verify connection
            client.start
            caps = client.capabilities
            has_capabilities = caps && (caps.is_a?(Hash) ? !caps.empty? : caps)

            elapsed = Time.now - start_time

            if client.alive? && has_capabilities
              # Success - get tools and record in context
              tools = begin
                client.tools
              rescue StandardError => tool_err
                log.warn("Failed to retrieve tools", server: name, error: tool_err.message)
                []
              end

              tool_names = tools.map { |t| t.respond_to?(:name) ? t.name : t.to_s }
              log.info("Connected successfully", server: name, elapsed_seconds: elapsed.round(2), tool_count: tools.size)
              log.debug("Available tools", server: name, tools: tool_names)

              result
                .with_context(name.to_sym, { status: :connected, tools: tools })
                .continue(result.value)
            else
              # Connection issue - determine specific error
              error = determine_mcp_connection_error(client, caps)
              log.warn("Connection failed", server: name, elapsed_seconds: elapsed.round(2), error: error)
              log.debug("Connection details", server: name, alive: client.alive?, capabilities: caps.inspect)

              result
                .with_error(name.to_sym, error)
                .with_context(name.to_sym, { status: :failed })
                .continue(result.value) # Continue to allow other servers
            end
          rescue StandardError => e
            elapsed = Time.now - start_time
            error_msg = e.message.downcase.include?('timeout') ?
              "Connection timed out" : e.message

            log.error("Connection exception", server: name, elapsed_seconds: elapsed.round(2), error_class: e.class.name, error: error_msg)
            log.debug("Exception backtrace", server: name, backtrace: e.backtrace&.first(3))

            result
              .with_error(name.to_sym, error_msg)
              .with_context(name.to_sym, { status: :failed })
              .continue(result.value)
          end
        }
      end

      def register_single_mcp_client(server)
        name    = server[:name]    || server['name']
        command = server[:command] || server['command']
        args    = server[:args]    || server['args'] || []
        env     = server[:env]     || server['env'] || {}

        raw_timeout = server[:timeout] || server['timeout'] ||
                      server[:request_timeout] || server['request_timeout'] ||
                      MCP_DEFAULT_TIMEOUT
        request_timeout = raw_timeout.to_i < 1000 ? (raw_timeout.to_i * 1000) : raw_timeout.to_i
        request_timeout = [request_timeout, 30_000].min

        logger.debug("Configuring client", server: name, command: command, args: args, timeout_ms: request_timeout)
        logger.debug("Environment variables", server: name, env_keys: env.keys) unless env.empty?

        mcp_config = { command: command, args: Array(args) }
        mcp_config[:env] = env unless env.empty?

        begin
          logger.debug("Adding client to RubyLLM::MCP with request_timeout", server: name)
          RubyLLM::MCP.add_client(
            name: name,
            transport_type: :stdio,
            config: mcp_config,
            request_timeout: request_timeout,
            start: false
          )
        rescue ArgumentError => e
          # If request_timeout isn't supported in this version, try without it
          if e.message.include?('timeout')
            logger.debug("Retrying without request_timeout (unsupported in this RubyLLM::MCP version)", server: name)
            RubyLLM::MCP.add_client(
              name: name,
              transport_type: :stdio,
              config: mcp_config,
              start: false
            )
          else
            logger.error("Failed to add client", server: name, error: e.message)
            raise
          end
        end

        logger.debug("Client registered successfully", server: name)
        RubyLLM::MCP.clients[name]
      end

      def determine_mcp_connection_error(client, caps)
        if !client.alive?
          "Connection failed"
        elsif caps.nil?
          "Connection timed out (no response)"
        elsif caps.is_a?(Hash) && caps.empty?
          "Connection timed out (empty capabilities)"
        else
          "Connection timed out (no capabilities received)"
        end
      end

      def extract_mcp_results(result, tools)
        logger.debug("Extracting MCP connection results from SimpleFlow pipeline")
        all_tools = []

        result.context.each do |server_name, info|
          name = server_name.to_s
          if info[:status] == :connected
            tool_count = (info[:tools] || []).size
            logger.debug("Extracting tools from connected server", server: name, tool_count: tool_count)
            AIA.config.connected_mcp_servers << name
            all_tools.concat(info[:tools] || [])
          end
        end

        result.errors.each do |server_name, messages|
          logger.debug("Recording failure", server: server_name, error: messages.first)
          AIA.config.failed_mcp_servers << {
            name: server_name.to_s,
            error: messages.first
          }
        end

        tools.concat(all_tools)

        logger.info("MCP results",
          connected_count: AIA.config.connected_mcp_servers.size,
          failed_count: AIA.config.failed_mcp_servers.size,
          total_tools: all_tools.size
        )

        # Report results
        report_mcp_connection_results(all_tools.size)
      end

      def report_mcp_connection_results(tool_count)
        if AIA.config.connected_mcp_servers.any?
          logger.info("Successfully connected", servers: AIA.config.connected_mcp_servers)
          $stderr.puts "MCP: Connected to #{AIA.config.connected_mcp_servers.join(', ')} (#{tool_count} tools)"
        end

        AIA.config.failed_mcp_servers.each do |failure|
          logger.warn("Server failed", server: failure[:name], error: failure[:error])
          $stderr.puts "  MCP: '#{failure[:name]}' failed - #{failure[:error]}"
        end

        if AIA.config.connected_mcp_servers.empty? && AIA.config.failed_mcp_servers.any?
          logger.error("No MCP servers connected successfully")
          $stderr.puts "MCP: No servers connected successfully"
        end

        $stderr.flush
      end
    end
  end
end
