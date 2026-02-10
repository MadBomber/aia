# lib/aia/adapter/gem_activator.rb
# frozen_string_literal: true

module AIA
  module Adapter
    class GemActivator
      # Activate a gem and add its lib path to $LOAD_PATH
      # This bypasses Bundler's restrictions on loading non-bundled gems
      def self.activate_gem_for_require(lib)
        return if Gem.try_activate(lib)

        gem_path = find_gem_path(lib)
        if gem_path
          lib_path = File.join(gem_path, 'lib')
          $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
        end
      end

      # Find gem path by searching gem directories directly
      # This bypasses Bundler's restrictions
      def self.find_gem_path(gem_name)
        gem_dirs = Gem.path.flat_map do |base|
          gems_dir = File.join(base, 'gems')
          next [] unless File.directory?(gems_dir)

          Dir.glob(File.join(gems_dir, "#{gem_name}-*")).select do |path|
            File.directory?(path) && File.basename(path).match?(/^#{Regexp.escape(gem_name)}-[\d.]+/)
          end
        end

        # Return the most recent version
        gem_dirs.sort.last
      end

      # Some tool libraries use lazy loading (e.g., Zeitwerk) and need explicit
      # triggering to load tool classes into ObjectSpace
      def self.trigger_tool_loading(lib)
        # Convert lib name to constant (e.g., 'shared_tools' -> SharedTools)
        const_name = lib.split(/[_-]/).map(&:capitalize).join

        begin
          mod = Object.const_get(const_name)

          # Try common methods that libraries use to load tools
          if mod.respond_to?(:load_all_tools)
            mod.load_all_tools
          elsif mod.respond_to?(:tools)
            # Calling .tools often triggers lazy loading
            mod.tools
          end
        rescue NameError
          # Constant doesn't exist, library might use different naming
        end
      end
    end
  end
end
