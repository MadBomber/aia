# frozen_string_literal: true

# lib/aia/model_registry.rb
#
# AIA's local copy of the RubyLLM model list, kept at
# <paths.aia_dir>/models.json and refreshed from the provider APIs every
# registry.refresh days (--refresh DAYS; 0 turns refreshing off).

require 'date'
require 'fileutils'

module AIA
  module ModelRegistry
    DEFAULT_REFRESH_DAYS = 7

    module_function

    # Point RubyLLM at AIA's models.json, refreshing it first when it is due.
    #
    # @param config [AIA::Config]
    def prepare(config)
      path = registry_path(config.paths&.aia_dir)
      return unless path

      days = refresh_days(config.registry&.refresh)
      if refresh_due?(path, days)
        refresh(path)
      elsif File.exist?(path)
        use(path)
      end
    end

    # @return [String, nil] the models.json path, or nil without an aia_dir
    def registry_path(aia_dir)
      return nil if aia_dir.to_s.strip.empty?

      File.join(File.expand_path(aia_dir), 'models.json')
    end

    # The refresh interval as a whole number of days; nil means the default.
    def refresh_days(value)
      return DEFAULT_REFRESH_DAYS if value.nil?

      [Integer(value.to_s, exception: false) || DEFAULT_REFRESH_DAYS, 0].max
    end

    # Whether +path+ is missing or more than +days+ days old. Never due when
    # +days+ is 0.
    def refresh_due?(path, days, today: Date.today)
      return false if days.zero?
      return true unless File.exist?(path)

      today > File.mtime(path).to_date + days
    end

    # Load the model list from +path+.
    def use(path)
      RubyLLM.config.model_registry_file = path
      RubyLLM.models.load_from_json(path)
    end

    # Refresh the model list from the provider APIs and save it to +path+.
    # On failure RubyLLM keeps the list it already had.
    def refresh(path)
      llm_config = RubyLLM.config
      previous   = llm_config.model_registry_file
      FileUtils.mkdir_p(File.dirname(path))
      llm_config.model_registry_file = path
      Speech.run_with_spinner("Refreshing the model list...") { RubyLLM.models.refresh }
    rescue StandardError => e
      llm_config&.model_registry_file = previous
      $stderr.puts "Warning: Could not refresh the model list (#{e.message}). Using the existing list."
    end
  end
end
