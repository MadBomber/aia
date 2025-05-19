# lib/aia.rb
#
# This is the main entry point for the AIA application.
# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.

require 'ruby_llm'

require 'prompt_manager'

require 'debug_me'
include DebugMe
$DEBUG_ME = false
DebugMeDefaultOptions[:skip1] = true

require_relative 'extensions/openstruct_merge'
require_relative 'aia/utility'
require_relative 'aia/version'
require_relative 'aia/config'
require_relative 'aia/shell_command_executor'
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
    @config.client = if @config.adapter == 'ruby_llm'
                      RubyLLMAdapter.new
                    else
                      AIClientAdapter.new
                    end

    session        = Session.new(prompt_handler)

    session.start
  end
end
