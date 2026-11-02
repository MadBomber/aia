# frozen_string_literal: true

module AIA
  # Loads, reloads, and unloads top-level Ruby plugin files from the configured
  # plugins directory. A plugin is any `*.rb` file directly under
  # `config.paths.plugins_dir`; it may define top-level (Kernel) methods and/or
  # top-level constants. The loader tracks exactly what each file defines so a
  # changed plugin can be cleanly reloaded and a deleted plugin fully removed
  # from the running process.
  class PluginLoader
    class << self
      # Per-process registry of loaded plugins, keyed by basename.
      # Each value: { path:, signature:, defined: { methods: [Symbol], constants: [Symbol] } }
      def registry
        @registry ||= {}
      end

      def mutex
        @mutex ||= Mutex.new
      end

      # Load every `*.rb` file at the top level of the plugins directory,
      # starting from a clean slate (any previously-tracked definitions are
      # removed first). Returns the sorted basenames of the loaded plugins.
      #
      # @param config [#paths, #loaded_plugins=]
      # @return [Array<String>]
      def load!(config)
        @config = config
        reset!(config)

        dir = plugins_dir(config)
        return [] unless dir

        Dir.glob(File.join(dir, '*.rb')).each { |file| load_file(file, config) }
        loaded_names
      end

      # Load — or, if already loaded, reload — a single plugin file. On reload,
      # the file's previous definitions are removed before re-executing so that
      # renamed/deleted methods don't linger. Returns the basename, or nil on
      # failure.
      #
      # @param path [String] absolute path to a `*.rb` plugin file
      # @param config [Object, nil] config to keep `loaded_plugins` in sync with
      # @return [String, nil]
      def load_file(path, config = @config)
        mutex.synchronize do
          name = File.basename(path, '.rb')
          remove_definitions(registry[name]) if registry.key?(name)

          before = current_definitions
          load(path)
          defined = diff_definitions(before, current_definitions)

          registry[name] = { path: path, signature: signature(path), defined: defined }
          sync_config(config)
          name
        end
      rescue ScriptError, StandardError => e
        warn_failure(path, e)
        nil
      end

      # Unload a plugin by basename: remove the methods and constants it defined
      # and forget it. Returns the basename if it was loaded, else nil.
      #
      # @param name [String] plugin basename (no extension)
      # @param config [Object, nil]
      # @return [String, nil]
      def unload_file(name, config = @config)
        mutex.synchronize do
          entry = registry.delete(name)
          remove_definitions(entry)
          sync_config(config)
          entry && name
        end
      end

      # @return [Array<String>] sorted basenames currently loaded
      def loaded_names
        registry.keys.sort
      end

      # Remove all tracked plugin definitions and clear the registry. Used by
      # load! for a clean reload and by tests for isolation.
      #
      # @param config [Object, nil]
      # @return [void]
      def reset!(config = @config)
        mutex.synchronize do
          registry.each_value { |entry| remove_definitions(entry) }
          registry.clear
          sync_config(config)
        end
      end

      private

      def plugins_dir(config)
        dir = config.paths&.plugins_dir
        return nil if dir.nil? || dir.to_s.strip.empty?
        return nil unless Dir.exist?(dir)

        dir
      end

      # Snapshot of the top-level methods and constants currently defined on
      # Object. Top-level `def` creates private instance methods on Object;
      # top-level constants/classes/modules become constants on Object.
      #
      # @return [Hash{Symbol=>Array<Symbol>}]
      def current_definitions
        {
          methods:   Object.private_instance_methods(false) + Object.instance_methods(false),
          constants: Object.constants(false)
        }
      end

      # What appeared between two snapshots.
      def diff_definitions(before, after)
        {
          methods:   after[:methods]   - before[:methods],
          constants: after[:constants] - before[:constants]
        }
      end

      # Remove the methods and constants a plugin defined, if still present and
      # owned directly by Object.
      def remove_definitions(entry)
        return unless entry

        defined = entry[:defined] || {}
        Array(defined[:methods]).each { |m| remove_object_method(m) }
        Array(defined[:constants]).each { |c| remove_object_constant(c) }
      end

      def remove_object_method(name)
        return unless Object.private_method_defined?(name, false) ||
                      Object.method_defined?(name, false)

        Object.send(:remove_method, name)
      rescue NameError
        # Already gone — nothing to do.
      end

      def remove_object_constant(name)
        Object.send(:remove_const, name) if Object.const_defined?(name, false)
      rescue NameError
        # Already gone — nothing to do.
      end

      # A cheap change-signature for a file: [mtime, size]. Nil if unreadable.
      def signature(path)
        stat = File.stat(path)
        [stat.mtime, stat.size]
      rescue SystemCallError
        nil
      end

      def sync_config(config)
        config.loaded_plugins = loaded_names if config.respond_to?(:loaded_plugins=)
      end

      def warn_failure(path, error)
        $stderr.puts "Warning: Failed to load plugin '#{path}': #{error.message}"
      end
    end
  end
end
