# lib/aia/config.rb
#
# This file contains the configuration settings for the AIA application.
# The Config class is responsible for managing configuration settings
# for the AIA application. It provides methods to parse command-line
# arguments, environment variables, and configuration files.

require_relative 'config/base'

module AIA
  class Config
    # Delegate all functionality to the modular config system
    def self.setup
      ConfigModules::Base.setup
    end

    # Maintain backward compatibility by delegating to Base module
    def self.method_missing(method_name, *args, &block)
      if ConfigModules::Base.respond_to?(method_name)
        ConfigModules::Base.send(method_name, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method_name, include_private = false)
      ConfigModules::Base.respond_to?(method_name, include_private) || super
    end
  end
end
