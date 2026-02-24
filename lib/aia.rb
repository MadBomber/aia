# lib/aia.rb
#
# Main entry point for the AIA application (v2).
# AIA is a thin CLI shell orchestrating robot_lab robots.

require 'robot_lab'
require 'pm'

require 'debug_me'
include DebugMe
$DEBUG_ME = false
DebugMeDefaultOptions[:skip1] = true

require_relative 'aia/errors'
require_relative 'aia/utility'
require_relative 'aia/version'
require_relative 'aia/config'
require_relative 'aia/logger'

# Top-level logger method available anywhere in the application
def logger
  AIA::LoggerManager.aia_logger
end

require_relative 'aia/config/cli_parser'
require_relative 'aia/config/validator'
require_relative 'aia/prompt_handler'
require_relative 'aia/robot_factory'
require_relative 'aia/directive_processor'
require_relative 'aia/history_manager'
require_relative 'aia/ui_presenter'
require_relative 'aia/input_collector'
require_relative 'aia/decisions'
require_relative 'aia/rules_dsl'
require_relative 'aia/rule_router'
require_relative 'aia/model_alias_registry'
require_relative 'aia/model_switch_handler'
require_relative 'aia/mcp_discovery'
require_relative 'aia/mcp_grouper'
require_relative 'aia/expert_router'
require_relative 'aia/verification_network'
require_relative 'aia/prompt_decomposer'
require_relative 'aia/session_tracker'
require_relative 'aia/trakflow_bridge'
require_relative 'aia/chat_loop'
require_relative 'aia/session'

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  at_exit do
    warn 'Exiting AIA application...'
  end

  @config = nil
  @client = nil

  class << self
    attr_accessor :config, :client

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
      ConfigValidator.tailor(@config)

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
      session.start
    end
  end
end
