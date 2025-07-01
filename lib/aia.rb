# lib/aia.rb
#
# This is the main entry point for the AIA application.
# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.

require 'ruby_llm'
require 'ruby_llm/mcp'

# FIXME: Actually fix ruby_llm; this is supposed to a temporary fix for the issues
#        discovered with shared_tools/ruby_llm/mcp/github_mcp_server
RubyLLM::MCP.support_complex_parameters!

require 'prompt_manager'


require 'debug_me'
include DebugMe
$DEBUG_ME = false
DebugMeDefaultOptions[:skip1] = true

require_relative 'extensions/openstruct_merge'    # adds self.merge self.get_value
require_relative 'extensions/ruby_llm/modalities' # adds model.modalities.text_to_text? etc.

require_relative 'refinements/string.rb'        # adds #include_any? #include_all?




require_relative 'aia/utility'
require_relative 'aia/version'
require_relative 'aia/config'
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
    STDERR.puts "Exiting AIA application..."
    # Clean up temporary STDIN file if it exists
    if @config&.stdin_temp_file && File.exist?(@config.stdin_temp_file)
      File.unlink(@config.stdin_temp_file)
    end
  end

  @config = nil

  def self.config
    @config
  end

  def self.client
    @config.client
  end

  def self.client=(client)
    @config.client = client
  end

  def self.good_file?(filename)
    File.exist?(filename) &&
    File.readable?(filename) &&
    !File.directory?(filename)
  end

  def self.bad_file?(filename)
    !good_file?(filename)
  end

  def self.build_flags
    @config.each_pair do |key, value|
      if [TrueClass, FalseClass].include?(value.class)
        define_singleton_method("#{key}?") do
          @config[key]
        end
      end
    end
  end

  def self.run
    @config = Config.setup

    build_flags

    # Load Fzf if fuzzy search is enabled and fzf is installed
    if @config.fuzzy && system('which fzf >/dev/null 2>&1')
      require_relative 'aia/fzf'
    end

    prompt_handler = PromptHandler.new

    # Initialize the appropriate client adapter based on configuration
    @config.client = if 'ruby_llm' == @config.adapter
                      RubyLLMAdapter.new
                    else
                      # TODO: ?? some other LLM API wrapper
                      STDERR.puts "ERROR: There is no adapter for #{@config.adapter}"
                      exit 1
                    end

    # There are two kinds of sessions: batch and chat
    # A chat session is started when the --chat CLI option is used
    # BUT its also possible to start a chat session with an initial prompt AND
    # within that initial prompt there can be a workflow (aka pipeline)
    # defined.  If that is the case, then the chat session will not start
    # until the initial prompt has completed its workflow.

    session        = Session.new(prompt_handler)

    session.start
  end
end
