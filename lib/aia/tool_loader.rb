# frozen_string_literal: true

# lib/aia/tool_loader.rb
#
# Tool loading, caching, filtering, and discovery.
# Extracted from RobotFactory to isolate the tool concern.
#
# ToolLoader is a class with instance-level cache state so that two instances
# have independent caches. Class-level convenience methods delegate to a
# resettable default instance (reset via ToolLoader.reset_instance! or AIA.reset!).

module AIA
  # :reek:TooManyMethods -- class-level delegators mirror the instance API; each loading step is its own small, testable method
  class ToolLoader
    class << self
      # Returns the shared default instance, creating it on first call.
      def instance
        @instance ||= new
      end

      # Discard the default instance. The next call to .instance creates a fresh one.
      # Called from AIA.reset! for test isolation.
      def reset_instance!
        @instance = nil
      end

      # Class-level convenience wrappers — delegate to the default instance.
      def cached_tools            = instance.cached_tools
      def clear_cache!            = instance.clear_cache!
      def load_tools(config)      = instance.load_tools(config)
      def require_libs(config)    = instance.require_libs(config)
      def filtered_tools(config)  = instance.filtered_tools(config)
      def discover_tools          = instance.discover_tools
      def eager_load_gem_tools    = instance.eager_load_gem_tools

      def activate_unbundled_gem(name)
        instance.activate_unbundled_gem(name)
      end
    end

    def initialize
      @tool_cache = nil
    end

    # Clear the cached tool discovery results.
    # Call when tool paths change via /config directive.
    def clear_cache!
      @tool_cache = nil
    end

    # Return the current tool cache (nil if not yet populated).
    def cached_tools
      @tool_cache
    end

    # Load tools from require_libs and tool paths, then cache the result.
    # Subsequent calls to RobotFactory.build skip this entirely if cache exists.
    # :reek:TooManyStatements -- sequential phases: require_libs, tool files, eager loads, discovery cache
    def load_tools(config)
      require_libs(config)

      # Load tool files from paths
      Array(config.tools&.paths).each do |path|
        expanded = File.expand_path(path)
        if File.exist?(expanded)
          require expanded
        else
          $stderr.puts "Warning: Tool file not found: #{path}"
        end
      rescue LoadError, StandardError => e
        $stderr.puts "Warning: Failed to load tool '#{path}': #{e.message}"
      end

      # Eagerly load tools from gems that use zeitwerk lazy loading
      # (e.g., shared_tools provides .load_all_tools for this purpose)
      eager_load_gem_tools

      # Re-register PM directives so any AIA::Directive subclasses defined
      # in just-loaded tool files become available in ERB prompt rendering.
      PM::Directive.register_all if defined?(PM::Directive)

      # Discover loaded tools via ObjectSpace and cache the result
      tools = discover_tools
      @tool_cache = tools
      config.loaded_tools = tools
      config.tool_names = tools.map { |t| ToolIntrospection.tool_name(t) }.join(', ')
    end

    # Require each --require library, activating an unbundled gem first when
    # needed. Safe to call more than once: Kernel#require skips loaded files.
    # Session calls it before connecting MCP servers, so mcp_servers: entries
    # can name RubyLLM::MCP subclasses those libraries define.
    def require_libs(config)
      Array(config.require_libs).each do |lib|
        require lib
      rescue LoadError
        # Not yet active — activate it (and its deps) via RubyGems, then retry
        if activate_unbundled_gem(lib)
          require lib rescue warn("Warning: Failed to require '#{lib}' after activation")
        else
          $stderr.puts "Warning: Failed to require '#{lib}': gem not found"
        end
      end
    end

    # Filter tools based on allowed/rejected lists and KBS decisions.
    # :reek:TooManyStatements -- allowed filter, rejected filter, then a name-dedup pass over the tool list
    # :reek:DuplicateMethodCall -- tool_name(t) is applied per element inside three separate filter blocks; no shared scope to hoist into
    def filtered_tools(config)
      tools = config.loaded_tools || []
      allowed = config.tools&.allowed
      rejected = config.tools&.rejected

      if allowed && !allowed.empty?
        allowed_list = Array(allowed).map(&:strip).map(&:downcase)
        tools = tools.select do |t|
          name = ToolIntrospection.tool_name(t).downcase
          # name is a String; Array#intersect? would raise TypeError
          allowed_list.any? { |a| name.include?(a) }
        end
      end

      if rejected && !rejected.empty?
        rejected_list = Array(rejected).map(&:strip).map(&:downcase)
        tools = tools.reject do |t|
          name = ToolIntrospection.tool_name(t).downcase
          # name is a String; Array#intersect? would raise TypeError
          rejected_list.any? { |r| name.include?(r) }
        end
      end

      seen = {}
      tools.select do |t|
        name = ToolIntrospection.tool_name(t)
        if seen[name]
          false
        else
          seen[name] = true
          true
        end
      end
    end

    # Discover RubyLLM::Tool subclasses from ObjectSpace.
    # Skips tools that report themselves as unavailable via #available?
    # (reported only under --debug, since that is a deliberate opt-out) and
    # tools whose class body never finished loading (always reported).
    def discover_tools
      return [] unless defined?(RubyLLM::Tool)

      candidates = ObjectSpace.each_object(Class).select { |klass| klass < RubyLLM::Tool && !mcp_tool_class?(klass) }
      incomplete, complete = candidates.partition { |klass| !implements_execute?(klass) }
      warn_incomplete_tools(incomplete.map { |klass| klass.name || klass.inspect })
      complete.select { |klass| available_tool?(klass) }
    end

    # True when the tool class can be instantiated and does not report
    # itself unavailable through #available? (reported only under --debug).
    def available_tool?(klass)
      instance = klass.new
      return true unless instance.respond_to?(:available?) && !instance.available?

      $stderr.puts "Info: Tool '#{ToolIntrospection.tool_name(instance)}' is not available, skipping" if AIA.debug?
      false
    rescue LoadError, StandardError
      false
    end

    # True for ruby_llm's RubyLLM::MCP::Tool (and subclasses): the wrapper an
    # MCP server's tools arrive in. They come from MCPConnectionManager, never
    # from ObjectSpace, and have no #execute of their own.
    def mcp_tool_class?(klass)
      defined?(RubyLLM::MCP::Tool) ? klass <= RubyLLM::MCP::Tool : false
    end

    # True when the tool class defines its own #execute. A class whose body
    # raised partway through (e.g. a gem written against an older RubyLLM
    # tool DSL) still inherits RubyLLM::Tool's abstract #execute and would
    # fail with NotImplementedError on the first tool call.
    def implements_execute?(klass)
      klass.instance_method(:execute).owner != RubyLLM::Tool
    end

    # One summary line for tool classes rejected by #implements_execute?.
    def warn_incomplete_tools(names)
      return if names.empty?

      $stderr.puts "Warning: #{names.size} tool(s) did not finish loading and were skipped " \
                   "(the gem providing them may need updating): #{names.sort.join(', ')}"
    end

    # Activate a gem that isn't yet active by asking RubyGems to activate it.
    # This adds its lib paths to $LOAD_PATH AND activates its dependencies,
    # unlike a manual $LOAD_PATH manipulation which would leave deps unresolved.
    #
    # Under bundler/setup (dev mode), `gem name` raises Gem::LoadError for any
    # gem not in the bundle. The fallback searches known gem install paths directly
    # and adds the lib dir to $LOAD_PATH so Zeitwerk-based gems still load.
    def activate_unbundled_gem(name)
      gem name
      true
    rescue Gem::LoadError
      lib_dir = [Gem.default_dir, Gem.user_dir].compact.flat_map do |d|
        Dir.glob("#{d}/gems/#{name}-*/lib")
      end.max
      return false unless lib_dir
      $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
      true
    rescue StandardError
      false
    end

    # Eagerly load tool classes from any required gem that uses lazy loading
    # (e.g. Zeitwerk). Calls .load_all_tools on every module that responds to it,
    # so any gem following that convention works — not just SharedTools.
    #
    # Gem::LoadError (a LoadError, not a StandardError) can fire when a tool's
    # dependency has a version conflict with an already-activated gem. The inner
    # rescue handles that per-module; the fallback loads constants one-at-a-time
    # so tools without conflicting deps still become available.
    def eager_load_gem_tools
      ObjectSpace.each_object(Module) do |mod|
        if mod.respond_to?(:load_all_tools)
          begin
            mod.load_all_tools
          rescue LoadError, StandardError
            eager_load_namespace_fallback(mod)
          end
        end
      rescue LoadError, StandardError
        next
      end
    rescue LoadError, StandardError => e
      $stderr.puts "Warning: Failed to eager-load gem tools: #{e.message}"
    end

    # Fallback when bulk load_all_tools fails: walk the module's namespace
    # recursively (up to 3 levels) and trigger each constant's autoload
    # individually, skipping any that raise a load error.
    def eager_load_namespace_fallback(mod, depth = 0)
      return if depth > 3
      mod.constants.each do |const_name|
        child = mod.const_get(const_name)
        eager_load_namespace_fallback(child, depth + 1) if child.is_a?(Module)
      rescue LoadError, StandardError
        next
      end
    end
  end
end
