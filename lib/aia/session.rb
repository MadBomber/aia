# frozen_string_literal: true

# lib/aia/session.rb
#
# Simplified orchestrator for AIA v2.
# Builds robot via RobotFactory, processes pipeline, enters chat.
# Integrates TrakFlow for pipeline tracking and session continuity.

require "tty-progressbar"
require "tty-screen"
require "reline"
require "pm"
require "json"
require "fileutils"
require "amazing_print"
require_relative "directive_processor"
require_relative "history_manager"
require_relative "ui_presenter"
require_relative "prompt_handler"
require_relative "utility"
require_relative "input_collector"
require_relative "robot_factory"
require_relative "rule_router"
require_relative "chat_loop"

module AIA
  class Session
    def initialize(prompt_handler)
      @prompt_handler = prompt_handler

      initialize_components
      setup_output_file
    end

    # Starts the session, processing all prompts in the pipeline and then
    # optionally starting an interactive chat session.
    def start
      # Apply rules before building robot
      @rule_router.evaluate(AIA.config)

      # Build robot or network
      @robot = RobotFactory.build(AIA.config)
      AIA.client = @robot

      # Eagerly connect MCP servers so the banner shows actual connection status
      connect_mcp_servers

      # Store session tracker globally for KBS access
      AIA.instance_variable_set(:@session_tracker, @session_tracker)

      # Handle special chat-only cases first
      if should_start_chat_immediately?
        AIA::Utility.robot
        check_trakflow_resume
        @chat_loop.start
        return
      end

      # Process all prompts in the pipeline
      process_pipeline

      # Start chat mode after all prompts are processed
      if AIA.chat?
        @chat_loop = build_chat_loop
        AIA::Utility.robot
        @ui_presenter.display_separator
        @chat_loop.start(skip_context_files: true)
      end
    end

    private

    def initialize_components
      @ui_presenter        = UIPresenter.new
      @directive_processor = DirectiveProcessor.new
      @input_collector     = InputCollector.new
      @rule_router         = RuleRouter.new
      @session_tracker     = SessionTracker.new
      @alias_registry      = ModelAliasRegistry.new(
        AIA.config.respond_to?(:model_aliases) ? (AIA.config.model_aliases || {}) : {}
      )
      @chat_loop           = nil  # created after robot is built
    end

    def setup_output_file
      out_file = AIA.config.output.file
      if out_file && !out_file.nil? && !AIA.append? && File.exist?(out_file)
        File.open(out_file, "w") { }
      end
    end

    def build_chat_loop
      ChatLoop.new(
        @robot, @ui_presenter, @directive_processor, @rule_router,
        session_tracker: @session_tracker,
        alias_registry: @alias_registry
      )
    end

    # Maximum seconds to wait for a single MCP server to connect and
    # return its tool list.  Keeps startup snappy even when a server hangs.
    MCP_CONNECT_TIMEOUT = 30

    # Connect ALL configured MCP servers eagerly at startup.
    # This MUST complete and be fully logged BEFORE the banner is displayed.
    # Only successfully connected server names appear in the banner.
    #
    # Handles each server independently so one failure doesn't block others.
    # Works with any version of robot_lab by using its public MCP::Client API
    # and injecting the results into the robot's instance variables.
    def connect_mcp_servers
      # Get MCP server configs: from the robot if it's a single Robot,
      # or from AIA config if it's a Network (Networks don't have mcp_config)
      servers = if @robot.respond_to?(:mcp_config) && @robot.mcp_config.is_a?(Array)
                  @robot.mcp_config
                else
                  RobotFactory.send(:mcp_server_configs, AIA.config)
                end
      return unless servers.is_a?(Array) && servers.any?

      logger = AIA::LoggerManager.mcp_logger
      server_names = servers.map { |s| s.is_a?(Hash) ? s[:name] : s.to_s }.compact
      logger.info("MCP initialization: connecting #{servers.size} server(s): #{server_names.join(', ')}")

      connected_clients = {}
      connected_tools   = []
      failed_servers    = []

      bar = TTY::ProgressBar.new(
        "Connecting MCP servers [:bar] :current/:total",
        total: servers.size,
        width: 20,
        output: $stderr
      )

      servers.each_with_index do |server_config, idx|
        name = server_config.is_a?(Hash) ? (server_config[:name] || server_config['name']) : server_config.to_s

        timeout = mcp_server_timeout(server_config)

        begin
          logger.info("MCP: connecting to '#{name}'...")
          Timeout.timeout(timeout) do
            client = RobotLab::MCP::Client.new(server_config)
            client.connect

            if client.connected?
              connected_clients[name] = client
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
                connected_tools << tool
              end
              logger.info("MCP: '#{name}' connected (#{tools.size} tools)")
            else
              failed_servers << { name: name, error: "connection failed" }
              logger.warn("MCP: '#{name}' failed to connect")
            end
          end
        rescue Timeout::Error
          failed_servers << { name: name, error: "timed out after #{timeout}s" }
          logger.warn("MCP: '#{name}' timed out after #{timeout}s")
        rescue StandardError => e
          failed_servers << { name: name, error: e.message }
          logger.warn("MCP: '#{name}' error: #{e.message}")
        ensure
          bar.advance
        end
      end

      bar.finish

      # Inject results so robots use these clients for tool calls.
      # For a Network, inject into each constituent robot.
      targets = if @robot.respond_to?(:robots) && @robot.robots.is_a?(Hash)
                  @robot.robots.values
                else
                  [@robot]
                end

      targets.each do |target|
        target.instance_variable_set(:@mcp_clients, connected_clients)
        target.instance_variable_set(:@mcp_tools, connected_tools)
        target.instance_variable_set(:@mcp_initialized, true)
      end

      # Record results for the banner
      AIA.config.connected_mcp_servers = connected_clients.keys
      AIA.config.failed_mcp_servers    = failed_servers

      logger.info("MCP initialization complete: #{connected_clients.size} connected, #{failed_servers.size} failed")
    end

    # Extract timeout in seconds from server config.
    # Config values >= 1000 are treated as milliseconds.
    def mcp_server_timeout(server_config)
      raw = server_config.is_a?(Hash) ? server_config[:timeout] : nil
      return MCP_CONNECT_TIMEOUT if raw.nil?

      seconds = raw.to_f
      seconds = seconds / 1000.0 if seconds >= 1000
      [seconds, MCP_CONNECT_TIMEOUT].min
    end

    # Check for resumable work in TrakFlow at session start
    def check_trakflow_resume
      bridge = TrakFlowBridge.new(@robot)
      return unless bridge.available?

      ready = bridge.check_ready_tasks
      return if ready.nil? || ready.to_s.strip.empty?

      @ui_presenter.display_info("Open tasks from previous sessions found:")
      @ui_presenter.display_info(ready.to_s)
    rescue StandardError
      # TrakFlow resume is best-effort
    end

    # Process all prompts in the pipeline via robot.run()
    def process_pipeline
      bridge = TrakFlowBridge.new(@robot)
      tracking = bridge.available? && AIA.config.flags.track_pipeline

      bridge.create_plan_from_pipeline(AIA.config.pipeline) if tracking

      AIA.config.pipeline.each do |prompt_id|
        next if prompt_id.nil? || prompt_id.empty?

        bridge.update_step_status(prompt_id, :started) if tracking

        prompt_text = build_prompt_text(prompt_id)
        next if prompt_text.nil? || prompt_text.strip.empty?

        # Check for concurrent MCP mode
        result = execute_prompt(prompt_text)
        content = extract_content(result)

        bridge.update_step_status(prompt_id, :completed) if tracking

        @session_tracker.record_turn(
          model: AIA.config.models.first.name,
          input: prompt_text,
          result: result
        )

        @ui_presenter.display_ai_response(content)
        output_to_file(content)
        display_metrics(result)
        @ui_presenter.display_separator
      rescue StandardError => e
        bridge.update_step_status(prompt_id, :failed, reason: e.message) if tracking
        raise
      end
    end

    # Execute a prompt, optionally using concurrent MCP
    def execute_prompt(prompt_text)
      concurrent_network = maybe_use_concurrent_mcp(prompt_text)

      if concurrent_network
        @ui_presenter.with_spinner("Processing (concurrent)") do
          concurrent_network.run(prompt_text)
        end
      else
        @ui_presenter.with_spinner("Processing") do
          if @robot.is_a?(RobotLab::Network)
            @robot.run(message: prompt_text)
          else
            @robot.run(prompt_text, mcp: :inherit, tools: :inherit)
          end
        end
      end
    end

    # Check if concurrent MCP mode should be used
    def maybe_use_concurrent_mcp(prompt_text)
      return nil unless (AIA.config.mcp_servers || []).size > 1

      # Check auto-concurrency config
      concurrency = AIA.config.respond_to?(:concurrency) ? AIA.config.concurrency : nil
      return nil unless concurrency&.auto || AIA.config.instance_variable_get(:@force_concurrent_mcp)

      # Clear force flag
      if AIA.config.instance_variable_get(:@force_concurrent_mcp)
        AIA.config.remove_instance_variable(:@force_concurrent_mcp)
      end

      discovery = MCPDiscovery.new(@rule_router)
      relevant_servers = discovery.discover(AIA.config, prompt_text)
      return nil if relevant_servers.size <= 1

      grouper = MCPGrouper.new
      groups = grouper.group(relevant_servers)

      threshold = concurrency&.respond_to?(:threshold) ? (concurrency.threshold || 2) : 2
      return nil if groups.size < threshold

      RobotFactory.build_concurrent_mcp_network(AIA.config, groups)
    rescue StandardError => e
      warn "Warning: Concurrent MCP setup failed: #{e.message}"
      nil
    end

    # Build prompt text from a prompt_id
    def build_prompt_text(prompt_id)
      parsed = @prompt_handler.fetch_prompt(prompt_id)
      return nil unless parsed

      # Collect parameter values if needed
      if parsed.respond_to?(:parameters) && parsed.parameters && !parsed.parameters.empty?
        values = @input_collector.collect(parsed.parameters)
        values.each { |k, v| parsed.parameters[k] = v }
      end

      prompt_text = parsed.to_s

      # Prepend role if configured
      role = AIA.config.prompts.role
      if role && !role.empty?
        role_parsed = @prompt_handler.fetch_role(role)
        if role_parsed
          prompt_text = "#{role_parsed}\n\n#{prompt_text}"
        end
      end

      # Append stdin content if available
      if AIA.config.stdin_content && !AIA.config.stdin_content.strip.empty?
        prompt_text = "#{prompt_text}\n\n#{AIA.config.stdin_content}"
        AIA.config.stdin_content = nil
      end

      # Append context files
      add_context_files(prompt_text)
    end

    # Append context file contents to prompt
    def add_context_files(prompt_text)
      context_files = AIA.config.context_files
      return prompt_text if context_files.nil? || context_files.empty?

      context = context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return prompt_text if context.strip.empty?

      "#{prompt_text}\n\n#{context}"
    end

    # Extract text content from a RobotResult or string
    def extract_content(result)
      if result.respond_to?(:reply)
        result.reply
      elsif result.respond_to?(:last_text_content)
        result.last_text_content
      elsif result.respond_to?(:content)
        result.content
      else
        result.to_s
      end
    end

    # Display token metrics if enabled
    def display_metrics(result)
      return unless AIA.config.flags.tokens

      # Extract metrics from RobotResult if available
      if result.respond_to?(:output) && result.output.any?
        last_msg = result.output.last
        if last_msg.respond_to?(:input_tokens)
          metrics = {
            model_id: result.robot_name,
            input_tokens: last_msg.input_tokens,
            output_tokens: last_msg.output_tokens
          }
          @ui_presenter.display_token_metrics(metrics)
        end
      end
    end

    # Write content to output file
    def output_to_file(content)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, 'a') do |file|
        file.puts "\nAI: #{content}"
      end
    end

    # Check if we should start chat immediately without processing any prompts
    def should_start_chat_immediately?
      return false unless AIA.chat?

      # Create chat loop now that robot is available
      @chat_loop = build_chat_loop

      AIA.config.pipeline.empty? || AIA.config.pipeline.all? { |id| id.nil? || id.empty? }
    end
  end
end
