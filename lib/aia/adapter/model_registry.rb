# lib/aia/adapter/model_registry.rb
# frozen_string_literal: true

require 'fileutils'
require 'json'

module AIA
  module Adapter
    class ModelRegistry
      def refresh
        return if models_json_path.nil? # Skip if no aia_dir configured

        # On first use, copy the bundled models.json from RubyLLM (no API calls)
        copy_bundled_models_to_local unless File.exist?(models_json_path)

        # Point RubyLLM at our local registry file for all model lookups
        RubyLLM.config.model_registry_file = models_json_path

        # Coerce refresh_days to integer (env vars come as strings)
        refresh_days = AIA.config.registry.refresh
        refresh_days = refresh_days.to_i if refresh_days.respond_to?(:to_i)
        refresh_days ||= 7 # Default to 7 days if nil

        # If refresh is disabled (0), just use the local file as-is
        return if refresh_days.zero?

        # Only refresh from provider APIs when enough days have elapsed
        last_refresh = models_last_refresh
        return unless last_refresh.nil? || Date.today > (last_refresh + refresh_days)

        # Refresh models from provider APIs and models.dev
        RubyLLM.models.refresh!

        # Save refreshed models to our local JSON file
        save_models_to_json
      end

      def models_json_path
        aia_dir = AIA.config.paths&.aia_dir
        return nil if aia_dir.nil?

        File.join(File.expand_path(aia_dir), 'models.json')
      end

      # Returns the last refresh date based on models.json modification time
      def models_last_refresh
        path = models_json_path
        return nil if path.nil? || !File.exist?(path)

        File.mtime(path).to_date
      end

      def copy_bundled_models_to_local
        aia_dir = File.expand_path(AIA.config.paths.aia_dir)
        FileUtils.mkdir_p(aia_dir)

        # RubyLLM.config.model_registry_file points to the gem's bundled models.json
        # before we redirect it to our local copy
        bundled_path = RubyLLM.config.model_registry_file

        if bundled_path && File.exist?(bundled_path)
          FileUtils.cp(bundled_path, models_json_path)
        else
          # Fallback: save whatever RubyLLM has loaded from its bundled data
          save_models_to_json
        end
      end

      def save_models_to_json
        return if models_json_path.nil?

        aia_dir = File.expand_path(AIA.config.paths.aia_dir)
        FileUtils.mkdir_p(aia_dir)

        models_data = RubyLLM.models.all.map(&:to_h)

        File.write(models_json_path, JSON.pretty_generate(models_data))
      end
    end
  end
end
