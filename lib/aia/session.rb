# frozen_string_literal: true

# lib/aia/session.rb
#
# Simplified orchestrator for AIA v2.
# Builds robot via RobotFactory, processes pipeline, enters chat.
# Integrates TrakFlow for pipeline tracking and session continuity.

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
    include ContentExtractor

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

      # Apply startup decisions (model selection, MCP filtering, gate warnings)
      applier = DecisionApplier.new(@ui_presenter)
      applier.apply(@rule_router.decisions, AIA.config, startup: true)

      # Build robot or network (uses KBS-adjusted config)
      @robot = RobotFactory.build(AIA.config)
      AIA.client = @robot

      # Eagerly connect MCP servers so the banner shows actual connection status
      connect_mcp_servers

      # Build tool filters based on active flags
      @filters = {}
      tools = all_available_tools

      if AIA.config.flags.tool_filter_a
        kbs_filter = ToolFilter::KBS.new(rule_router: @rule_router, tools: tools)
        kbs_filter.prep
        @filters[:kbs] = kbs_filter
      else
        # Still need register_tools for evaluate_turn even when KBS filter is off
        @rule_router.register_tools(tools)
      end

      if AIA.config.flags.tool_filter_b
        fact_asserter = FactAsserter.new
        tfidf_filter = ToolFilter::TFIDF.new(tools: tools, fact_asserter: fact_asserter)
        tfidf_filter.prep
        @filters[:tfidf] = tfidf_filter
      end

      if AIA.config.flags.tool_filter_c
        fact_asserter ||= FactAsserter.new
        zvec_filter = ToolFilter::Zvec.new(
          tools: tools, fact_asserter: fact_asserter,
          db_dir:  AIA.config.paths.aia_dir,
          load_db: AIA.config.flags.tool_filter_load,
          save_db: AIA.config.flags.tool_filter_save
        )
        zvec_filter.prep
        @filters[:zvec] = zvec_filter
      end

      if AIA.config.flags.tool_filter_d
        fact_asserter ||= FactAsserter.new
        sqvec_filter = ToolFilter::SqliteVec.new(
          tools: tools, fact_asserter: fact_asserter,
          db_dir:  AIA.config.paths.aia_dir,
          load_db: AIA.config.flags.tool_filter_load,
          save_db: AIA.config.flags.tool_filter_save
        )
        sqvec_filter.prep
        @filters[:sqlite_vec] = sqvec_filter
      end

      if AIA.config.flags.tool_filter_e
        fact_asserter ||= FactAsserter.new
        lsi_filter = ToolFilter::LSI.new(
          tools: tools, fact_asserter: fact_asserter,
          db_dir:  AIA.config.paths.aia_dir,
          load_db: AIA.config.flags.tool_filter_load,
          save_db: AIA.config.flags.tool_filter_save
        )
        lsi_filter.prep
        @filters[:lsi] = lsi_filter
      end

      # Initialize task coordination if TrakFlow is available
      initialize_task_coordinator

      # Attach shared bus to multi-model networks
      attach_bus_if_network

      # Store session tracker globally for KBS access
      AIA.session_tracker = @session_tracker

      # Handle special chat-only cases first
      if should_start_chat_immediately?
        AIA::Utility.robot
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

      AIA.rule_router      = @rule_router
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
        alias_registry: @alias_registry,
        filters: @filters
      )
    end

    # Connect ALL configured MCP servers eagerly at startup.
    # Delegates to MCPConnectionManager which owns all MCP connection state.
    def connect_mcp_servers
      servers = if @robot.respond_to?(:mcp_config) && @robot.mcp_config.is_a?(Array)
                  @robot.mcp_config
                else
                  RobotFactory.mcp_server_configs(AIA.config)
                end
      return unless servers.is_a?(Array) && servers.any?

      @mcp_manager = MCPConnectionManager.new
      @mcp_manager.connect_all(servers)
      @mcp_manager.inject_into(@robot)
      @mcp_manager.update_config
    end

    # Initialize TaskCoordinator, auto-creating the TrakFlow project if needed.
    def initialize_task_coordinator
      ensure_trakflow_initialized unless TrakFlow.initialized?

      AIA.task_coordinator = TaskCoordinator.new
      AIA.task_coordinator.clear!
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

    # Collect all tools available to the robot: local + MCP.
    def all_available_tools
      local = Array(AIA.config.loaded_tools)
      mcp   = collect_mcp_tools
      local + mcp
    end

    # Retrieve MCP tools from all connected MCP clients.
    def collect_mcp_tools
      defined?(RubyLLM::MCP) ? RubyLLM::MCP.clients.values.flat_map(&:tools) : []
    end

    # Process all prompts in the pipeline via robot.run()
    def process_pipeline
      bridge = TrakFlowBridge.new
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
      return nil unless concurrency&.auto || AIA.turn_state.force_concurrent_mcp

      # Clear force flag
      if AIA.turn_state.force_concurrent_mcp
        AIA.turn_state.force_concurrent_mcp = false
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

    # Check if we should start chat immediately without processing any prompts
    def should_start_chat_immediately?
      return false unless AIA.chat?

      # Create chat loop now that robot is available
      @chat_loop = build_chat_loop

      AIA.config.pipeline.empty? || AIA.config.pipeline.all? { |id| id.nil? || id.empty? }
    end
  end
end
