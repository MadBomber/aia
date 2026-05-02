# lib/aia.rb
#
# Main entry point for the AIA application (v2).
# AIA is a thin CLI shell orchestrating robot_lab robots.

gem 'bigdecimal', '>= 4.0'
require 'bigdecimal'
require 'robot_lab'
require 'pm'

require_relative 'aia/patches/ruby_llm_tool_error'

require_relative 'aia/errors'
require_relative 'aia/turn_state'
require_relative 'aia/content_extractor'
require_relative 'aia/utility'
require_relative 'aia/skill_utils'
require_relative 'aia/version'
require_relative 'aia/config'
require_relative 'aia/logger'

require_relative 'aia/config/cli_parser'
require_relative 'aia/config/validator'
require_relative 'aia/prompt_handler'
require_relative 'aia/tool_loader'
require_relative 'aia/system_prompt_assembler'
require_relative 'aia/mcp_config_normalizer'
require_relative 'aia/network_memory_manager'
require_relative 'aia/robot_factory'
require_relative 'aia/robot_builder'
require_relative 'aia/directive_processor'
require_relative 'aia/variable_input_collector'
require_relative 'aia/ui_presenter'
require_relative 'aia/input_collector'
require_relative 'aia/handler_context'
require_relative 'aia/handler_protocol'
require_relative 'aia/model_alias_registry'
require_relative 'aia/model_switch_handler'
require_relative 'aia/mcp_discovery'
require_relative 'aia/mcp_grouper'
require_relative 'aia/cost_calculator'
require_relative 'aia/session_tracker'
require_relative 'aia/similarity_scorer'
require_relative 'aia/fact_asserter'
require_relative 'aia/tool_filter'
require_relative 'aia/tool_filter_registry'
require_relative 'aia/tool_filter_strategy'
require_relative 'aia/streaming_runner'
require_relative 'aia/mention_router'
require_relative 'aia/special_mode_handler'
require_relative 'aia/mcp_connection_manager'
require_relative 'aia/startup_coordinator'
require_relative 'aia/pipeline_orchestrator'
require_relative 'aia/chat_loop'
require_relative 'aia/session'

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  require 'debug_me'
  include DebugMe
  $DEBUG_ME = false
  DebugMeDefaultOptions[:skip1] = true

  at_exit do
    warn 'Exiting AIA application...'
  end

  @config = nil
  @client = nil
  @session_tracker = nil
  @turn_state = TurnState.new

  class << self
    attr_accessor :config, :client, :session_tracker, :turn_state, :task_coordinator

    def logger
      AIA::LoggerManager.aia_logger
    end

    def reset!
      @config = @client = @session_tracker = @turn_state =
        @task_coordinator = nil
      ToolLoader.reset_instance!
    end

    def good_file?(filename)
      File.exist?(filename) &&
        File.readable?(filename) &&
        !File.directory?(filename)
    end

    def bad_file?(filename)
      !good_file?(filename)
    end

    # Convenience flag accessors (delegate to config.flags section)
    def chat?
      @config&.flags&.chat == true
    end

    def debug?
      @config&.flags&.debug == true
    end

    # Emit a warning always; if --debug is active and an exception is given,
    # also print the first 5 backtrace frames so errors are diagnosable.
    #
    # @param msg [String]
    # @param exc [Exception, nil]
    def debug_warn(msg, exc: nil)
      warn msg
      return unless exc && exc.backtrace && config&.flags&.debug
      warn exc.backtrace.first(5).join("\n")
    end

    def verbose?
      @config&.flags&.verbose == true
    end

    def fuzzy?
      @config&.flags&.fuzzy == true
    end

    def speak?
      @config&.flags&.speak == true
    end

    def append?
      @config&.output&.append == true
    end

    def run
      # Parse CLI arguments
      cli_overrides = CLIParser.parse

      # Create config with CLI overrides
      @config = Config.setup(cli_overrides)

      # Validate and tailor configuration (handles --dump early exit)
      return if ConfigValidator.tailor(@config) == :early_exit

      # Configure RobotLab loggers and providers once at startup
      RobotFactory.setup(@config)

      # Load Fzf if fuzzy search is enabled and fzf is installed
      if @config.flags.fuzzy
        begin
          if system('which fzf >/dev/null 2>&1')
            require_relative 'aia/fzf'
          else
            warn 'Warning: Fuzzy search enabled but fzf not found. Install fzf for enhanced search capabilities.'
          end
        rescue StandardError => e
          warn "Warning: Failed to load fzf: #{e.message}"
        end
      end

      prompt_handler = PromptHandler.new

      # In v2, robot is built by RobotFactory inside Session.start
      # AIA.client is set there as well.

      session = Session.new(prompt_handler)
      at_exit { session.cleanup }
      session.start
    rescue AIA::ConfigurationError => e
      warn e.message
      exit 1
    rescue AIA::Error => e
      warn e.message
      exit 1
    end
  end
end
