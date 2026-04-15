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
require_relative "variable_input_collector"
require_relative "ui_presenter"
require_relative "prompt_handler"
require_relative "utility"
require_relative "input_collector"
require_relative "robot_factory"
require_relative "tool_filter_registry"
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
      # Build robot or network
      @robot = RobotFactory.build(AIA.config)
      AIA.client = @robot

      # Run all startup coordination: MCP, tools, filters, task board, bus
      coordinator = StartupCoordinator.new(robot: @robot, ui_presenter: @ui_presenter)
      coordinator.run(AIA.config)
      @filters     = coordinator.filters
      @mcp_manager = coordinator.mcp_manager

      # Store session tracker globally for KBS access
      AIA.session_tracker = @session_tracker

      # Handle special chat-only cases first
      if should_start_chat_immediately?
        AIA::Utility.robot
        @chat_loop.start
        return
      end

      # Process all prompts in the pipeline
      PipelineOrchestrator.new(
        robot:           @robot,
        prompt_handler:  @prompt_handler,
        input_collector: @input_collector,
        ui_presenter:    @ui_presenter,
        session_tracker: @session_tracker
      ).process(AIA.config)

      # Start chat mode after all prompts are processed
      if AIA.chat?
        @chat_loop = build_chat_loop
        AIA::Utility.robot
        @ui_presenter.display_separator
        @chat_loop.start(skip_context_files: true)
      end
    end

    # Release all held resources: MCP connections and filter state.
    # Called automatically via at_exit registered in #start.
    # Safe to call multiple times.
    def cleanup
      @mcp_manager&.close_all
      @filters&.each_value(&:cleanup)
    end

    private

    def initialize_components
      @ui_presenter        = UIPresenter.new
      @directive_processor = DirectiveProcessor.new
      @input_collector     = InputCollector.new

      @session_tracker     = SessionTracker.new
      @alias_registry      = ModelAliasRegistry.new(
        AIA.config.respond_to?(:model_aliases) ? (AIA.config.model_aliases || {}) : {}
      )
      @chat_loop           = nil  # created after robot is built

      rotate_history_log_if_needed
    end

    MAX_HISTORY_BYTES = 10 * 1024 * 1024  # 10 MB

    # Rotate the prompt history log if it has grown too large.
    # Renames <file> to <file>.1 so the next session starts fresh.
    # Called once at session initialization.
    def rotate_history_log_if_needed
      history_file = AIA.config.output.history_file
      return unless history_file && File.exist?(history_file)
      return unless File.size(history_file) > MAX_HISTORY_BYTES

      archive = "#{history_file}.1"
      FileUtils.mv(history_file, archive)
      warn "History log rotated: #{File.basename(history_file)} → #{File.basename(archive)}"
    rescue StandardError => e
      warn "Warning: Could not rotate history log: #{e.message}"
    end

    def setup_output_file
      out_file = AIA.config.output.file
      if out_file && !out_file.nil? && !AIA.append? && File.exist?(out_file)
        File.open(out_file, "w") { }
      end
    end

    def build_chat_loop
      ChatLoop.new(
        @robot, @ui_presenter, @directive_processor,
        session_tracker: @session_tracker,
        alias_registry: @alias_registry,
        filters: @filters
      )
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
