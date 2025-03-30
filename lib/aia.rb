# lib/aia.rb
#
# This is the main entry point for the AIA application.
# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.

require 'ai_client'
require 'prompt_manager'
require 'debug_me'
include DebugMe

require_relative 'aia/version'
require_relative 'aia/config'
require_relative 'aia/shell_command_executor'
require_relative 'aia/prompt_handler'
require_relative 'aia/ai_client_adapter'
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

  def self.build_flags
    @config.each_pair do |key, value|
      if [TrueClass, FalseClass].include?(value.class)
        define_singleton_method("#{key}?") do
          @config[key]
        end
      end
    end
  end

  def self.run(args)
    @config = Config.parse(args)

    build_flags

    prompt_handler = PromptHandler.new
    client         = AIClientAdapter.new
    session        = Session.new(prompt_handler, client)

    session.start
  end
end
