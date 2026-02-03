# lib/aia.rb
#
# This is the main entry point for the AIA application.
# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.

require 'ruby_llm'
require 'ruby_llm/mcp'

# NOTE: Complex parameters are now supported natively in ruby_llm-mcp >= 0.8.0
#       The support_complex_parameters! method has been removed.

require 'pm'


require 'debug_me'
include DebugMe
$DEBUG_ME = false
DebugMeDefaultOptions[:skip1] = true

require_relative 'extensions/openstruct_merge'    # adds self.merge self.get_value
require_relative 'extensions/ruby_llm/modalities' # adds model.modalities.text_to_text? etc.

require_relative 'refinements/string' # adds #include_any? #include_all?

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
require_relative 'aia/ruby_llm_adapter'
require_relative 'aia/directive_processor'
require_relative 'aia/history_manager'
require_relative 'aia/ui_presenter'
require_relative 'aia/chat_processor_service'
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

      @client = RubyLLMAdapter.new

      # There are two kinds of sessions: batch and chat
      # A chat session is started when the --chat CLI option is used
      # BUT its also possible to start a chat session with an initial prompt AND
      # within that initial prompt there can be a workflow (aka pipeline)
      # defined.  If that is the case, then the chat session will not start
      # until the initial prompt has completed its workflow.

      session = Session.new(prompt_handler)
      session.start
    end
  end
end
