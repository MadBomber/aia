# This file is the main entry point for the gem.

module AIA
  class << self
    attr_accessor :config, :client
  end
end

# Ensure that all core components are loaded.
require_relative "aia/config"
require_relative "aia/setup_helpers"
require_relative "aia/cli"
require_relative "aia/client"
require_relative "aia/directives"
require_relative "aia/dynamic_content"
require_relative "aia/prompt"
require_relative "aia/logging"

require_relative "aia/fzf"

require_relative "aia/user_query"
require_relative "aia/client_manager"
require_relative "aia/response_handler"
require_relative "aia/prompt_processor"
require_relative "aia/chat_manager"
require_relative "aia/pipeline_processor"
require_relative "aia/configuration_validator"

module AIA
  # ... additional gem setup if needed ...
end
