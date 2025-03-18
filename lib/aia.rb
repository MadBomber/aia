# lib/aia.rb
#
# This is the main entry point for the AIA application.

require 'ai_client'
require 'prompt_manager'
require 'debug_me'
include DebugMe

require_relative 'aia/version'
require_relative 'aia/config'
require_relative 'aia/prompt_handler'
require_relative 'aia/ai_client_adapter'
require_relative 'aia/session'

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  # Main entry point
  # Runs the AIA application with the given command-line arguments.
  #
  # @param args [Array<String>] the command-line arguments
  def self.run(args)
    config = Config.parse(args)
    prompt_handler = PromptHandler.new(config)
    client = AIClientAdapter.new(config)
    session = Session.new(config, prompt_handler, client)

    session.start
  end
end
