# lib/aia/adapter/tool_loader.rb
# frozen_string_literal: true

module AIA
  module Adapter
    class ToolLoader
      def initialize(mcp_connector)
        @mcp_connector = mcp_connector
      end

      def load_tools_with_mcp
        tools = []

        tools += scan_local_tools
        @mcp_connector.support_mcp_with_simple_flow(tools)
        tools
      end

      def load_tools_legacy
        tools = []

        tools += scan_local_tools
        @mcp_connector.support_mcp(tools)
        tools
      end

      def scan_local_tools
        tools = []

        # First, load any required libraries specified in config
        load_require_libs

        # Then, load tool files from tools.paths
        load_tool_files

        # Now scan ObjectSpace for RubyLLM::Tool subclasses
        tool_classes = ObjectSpace.each_object(Class).select do |klass|
          next false unless klass < RubyLLM::Tool

          # Filter out tools that can't be instantiated without arguments
          # RubyLLM calls tool.new without args, so we must verify each tool works
          begin
            klass.new
            true
          rescue ArgumentError, LoadError, StandardError
            # Skip tools that require arguments or have missing dependencies
            false
          end
        end

        tools + tool_classes
      end

      private

      def load_require_libs
        require_libs = AIA.config.require_libs
        return if require_libs.nil? || require_libs.empty?

        require_libs.each do |lib|
          begin
            # Activate gem and add to load path (bypasses Bundler's restrictions)
            GemActivator.activate_gem_for_require(lib)

            require lib

            # After requiring, trigger tool loading if the library supports it
            # This handles gems like shared_tools that use Zeitwerk lazy loading
            GemActivator.trigger_tool_loading(lib)
          rescue LoadError => e
            warn "Warning: Failed to require library '#{lib}': #{e.message}"
            warn "Hint: Make sure the gem is installed: gem install #{lib}"
          rescue StandardError => e
            warn "Warning: Error in library '#{lib}': #{e.class} - #{e.message}"
          end
        end
      end

      def load_tool_files
        paths = AIA.config.tools&.paths
        return if paths.nil? || paths.empty?

        paths.each do |path|
          expanded_path = File.expand_path(path)
          if File.exist?(expanded_path)
            begin
              require expanded_path
            rescue LoadError, StandardError => e
              warn "Warning: Failed to load tool file '#{path}': #{e.message}"
            end
          else
            warn "Warning: Tool file not found: #{path}"
          end
        end
      end
    end
  end
end
