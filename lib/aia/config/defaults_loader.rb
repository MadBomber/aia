# frozen_string_literal: true

# lib/aia/config/defaults_loader.rb
#
# Bundled Defaults Loader for Anyway Config
#
# Loads default configuration values from defaults.yml bundled with the gem.
# This ensures defaults are always available regardless of where AIA is installed.
#
# This loader runs at LOWEST priority, so all other sources can override:
# 1. Bundled defaults (this loader)
# 2. User config (~/.aia/config.yml)
# 3. Environment variables (AIA_*)
# 4. CLI arguments (applied separately)

require 'anyway_config'
require 'yaml'

module AIA
  module Loaders
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
  end
end

# Register the defaults loader at LOWEST priority (before :yml loader)
# This ensures bundled defaults are overridden by all other sources
Anyway.loaders.insert_before :yml, :bundled_defaults, AIA::Loaders::DefaultsLoader
