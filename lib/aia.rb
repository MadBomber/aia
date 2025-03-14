# frozen_string_literal: true

require 'ai_client'
require 'prompt_manager'

require_relative 'aia/version'
require_relative 'aia/config'
require_relative 'aia/prompt_handler'
require_relative 'aia/ai_client_adapter'
require_relative 'aia/session'

module AIA
  # Main entry point
  def self.run(args)
    config = Config.parse(args)
    prompt_handler = PromptHandler.new(config)
    client = AIClientAdapter.new(config)
    session = Session.new(config, prompt_handler, client)

    session.start
  end
end
