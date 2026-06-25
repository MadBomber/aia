# frozen_string_literal: true

module AIA
  class PluginLoader
    class << self
      def load!(config)
        plugins_dir = config.paths&.plugins_dir
        config.loaded_plugins = [] if config.respond_to?(:loaded_plugins=)

        return [] if plugins_dir.nil? || plugins_dir.to_s.strip.empty?
        return [] unless Dir.exist?(plugins_dir)

        loaded = []

        Dir.glob(File.join(plugins_dir, '*.rb')).sort.each do |plugin_file|
          require plugin_file
          loaded << File.basename(plugin_file, '.rb')
        rescue LoadError, StandardError => e
          $stderr.puts "Warning: Failed to load plugin '#{plugin_file}': #{e.message}"
        end

        config.loaded_plugins = loaded if config.respond_to?(:loaded_plugins=)
        loaded
      end
    end
  end
end
