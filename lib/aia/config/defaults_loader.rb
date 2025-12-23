# frozen_string_literal: true

# lib/aia/config/defaults_loader.rb
#
# Configuration Loaders for Anyway Config
#
# Provides two custom loaders:
# 1. DefaultsLoader - Loads bundled defaults from defaults.yml
# 2. UserConfigLoader - Loads user config from ~/.config/aia/aia.yml
#
# Loading priority (lowest to highest):
# 1. Bundled defaults (DefaultsLoader)
# 2. User config (UserConfigLoader)
# 3. Environment variables (AIA_*)
# 4. CLI arguments (applied separately)

require 'anyway_config'
require 'yaml'

module AIA
  module Loaders
    # Loads bundled default configuration values from defaults.yml
    class DefaultsLoader < Anyway::Loaders::Base
      DEFAULTS_PATH = File.expand_path('../defaults.yml', __FILE__).freeze

      class << self
        # Returns the path to the bundled defaults file
        #
        # @return [String] path to defaults.yml
        def defaults_path
          DEFAULTS_PATH
        end

        # Check if defaults file exists
        #
        # @return [Boolean]
        def defaults_exist?
          File.exist?(DEFAULTS_PATH)
        end

        # Load and parse the raw YAML content
        #
        # @return [Hash] parsed YAML with symbolized keys
        def load_raw_yaml
          return {} unless defaults_exist?

          content = File.read(defaults_path)
          YAML.safe_load(
            content,
            permitted_classes: [Symbol, Date],
            symbolize_names: true,
            aliases: true
          ) || {}
        rescue Psych::SyntaxError => e
          warn "AIA: Failed to parse bundled defaults #{defaults_path}: #{e.message}"
          {}
        end

        # Returns the schema (all configuration keys and their defaults)
        #
        # @return [Hash] the complete defaults
        def schema
          load_raw_yaml
        end

        # Get a list of all top-level configuration sections
        #
        # @return [Array<Symbol>] list of section names
        def sections
          schema.keys
        end
      end

      # Called by Anyway Config to load configuration
      #
      # @param name [Symbol] the config name (unused, always :aia)
      # @return [Hash] configuration hash
      def call(name:, **_options)
        return {} unless self.class.defaults_exist?

        trace!(:bundled_defaults, path: self.class.defaults_path) do
          self.class.load_raw_yaml
        end
      end
    end

    # Loads user configuration from XDG config directory
    # Follows XDG Base Directory Specification: ~/.config/aia/aia.yml
    class UserConfigLoader < Anyway::Loaders::Base
      class << self
        # Returns the path to the user config file
        # Uses XDG_CONFIG_HOME if set, otherwise defaults to ~/.config
        #
        # @return [String] path to user config file
        def user_config_path
          xdg_config_home = ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config'))
          File.join(xdg_config_home, 'aia', 'aia.yml')
        end

        # Check if user config file exists
        #
        # @return [Boolean]
        def user_config_exist?
          File.exist?(user_config_path)
        end

        # Load and parse the user YAML content
        #
        # @return [Hash] parsed YAML with symbolized keys
        def load_user_yaml
          return {} unless user_config_exist?

          content = File.read(user_config_path)
          YAML.safe_load(
            content,
            permitted_classes: [Symbol, Date],
            symbolize_names: true,
            aliases: true
          ) || {}
        rescue Psych::SyntaxError => e
          warn "AIA: Failed to parse user config #{user_config_path}: #{e.message}"
          {}
        end
      end

      # Called by Anyway Config to load configuration
      #
      # @param name [Symbol] the config name (unused, always :aia)
      # @return [Hash] configuration hash
      def call(name:, **_options)
        return {} unless self.class.user_config_exist?

        trace!(:user_config, path: self.class.user_config_path) do
          self.class.load_user_yaml
        end
      end
    end
  end
end

# Register loaders in priority order (lowest to highest)
# 1. bundled_defaults - gem's default values
# 2. user_config - user's ~/.config/aia/aia.yml
# 3. yml - standard anyway_config yml loader (for config/aia.yml in app directory)
# 4. env - environment variables
Anyway.loaders.insert_before :yml, :bundled_defaults, AIA::Loaders::DefaultsLoader
Anyway.loaders.insert_after :bundled_defaults, :user_config, AIA::Loaders::UserConfigLoader
