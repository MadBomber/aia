# frozen_string_literal: true

require 'aia/version'
require 'aia/config'
require 'aia/prompt_handler'
require 'aia/ai_client_adapter'
require 'aia/session'

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
