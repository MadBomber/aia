# lib/aia/directives/registry.rb
#
# Loads all directive implementation modules.
# Dispatch is handled by PM.directives (registered in PromptHandler#register_pm_directives).
# The Registry module is retained for organizational grouping and help/alias metadata.

require_relative 'web_and_file'
require_relative 'utility'
require_relative 'configuration'
require_relative 'execution'
require_relative 'models'
require_relative 'checkpoint'

module AIA
  module Directives
    module Registry
      DIRECTIVE_MODULES = [
        WebAndFile,
        Utility,
        Configuration,
        Execution,
        Models,
        Checkpoint
      ].freeze
    end
  end
end
