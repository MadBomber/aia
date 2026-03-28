# frozen_string_literal: true

# lib/aia/tool_loader.rb
#
# Tool loading, caching, filtering, and discovery.
# Extracted from RobotFactory to isolate the tool concern.

module AIA
  module ToolLoader
    module_function

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
    def load_tools(config)
      Array(config.require_libs).each do |lib|
        begin
          require lib
        rescue LoadError
          # Not yet active — activate it (and its deps) via RubyGems, then retry
          if activate_unbundled_gem(lib)
            require lib rescue warn("Warning: Failed to require '#{lib}' after activation")
          else
            warn "Warning: Failed to require '#{lib}': gem not found"
          end
        end
      end

      # Load tool files from paths
      Array(config.tools&.paths).each do |path|
        expanded = File.expand_path(path)
        if File.exist?(expanded)
          require expanded
        else
          warn "Warning: Tool file not found: #{path}"
        end
      rescue LoadError, StandardError => e
        warn "Warning: Failed to load tool '#{path}': #{e.message}"
      end

      # Eagerly load tools from gems that use zeitwerk lazy loading
      # (e.g., shared_tools provides .load_all_tools for this purpose)
      eager_load_gem_tools

      # Discover loaded tools via ObjectSpace and cache the result
      tools = discover_tools
      @tool_cache = tools
      config.loaded_tools = tools
      config.tool_names = tools.map { |t| t.respond_to?(:name) ? t.name : t.class.name }.join(', ')
    end

    # Filter tools based on allowed/rejected lists and KBS decisions.
    def filtered_tools(config)
      tools = config.loaded_tools || []
      allowed = config.tools&.allowed
      rejected = config.tools&.rejected

      if allowed && !allowed.empty?
        allowed_list = Array(allowed).map(&:strip).map(&:downcase)
        tools = tools.select do |t|
          name = (t.respond_to?(:name) ? t.name : t.class.name).downcase
          allowed_list.any? { |a| name.include?(a) }
        end
      end

      if rejected && !rejected.empty?
        rejected_list = Array(rejected).map(&:strip).map(&:downcase)
        tools = tools.reject do |t|
          name = (t.respond_to?(:name) ? t.name : t.class.name).downcase
          rejected_list.any? { |r| name.include?(r) }
        end
      end

      # KBS-driven tool filtering (per-turn or startup).
      # Only applies when user has not explicitly used --allowed-tools or --rejected-tools.
      kbs_active = AIA.turn_state&.active_tools
      if kbs_active && !kbs_active.empty? && (allowed.nil? || allowed.empty?) && (rejected.nil? || rejected.empty?)
        tools = tools.select do |t|
          name = (t.respond_to?(:name) ? t.name : t.class.name)
          kbs_active.include?(name)
        end
      end

      seen = {}
      tools.select do |t|
        name = t.respond_to?(:name) ? t.name : t.class.name
        if seen[name]
          false
        else
          seen[name] = true
          true
        end
      end
    end

    # Discover RubyLLM::Tool subclasses from ObjectSpace.
    # Skips tools that report themselves as unavailable via #available?.
    def discover_tools
      ObjectSpace.each_object(Class).select do |klass|
        next false unless defined?(RubyLLM::Tool) && klass < RubyLLM::Tool
        begin
          instance = klass.new
          if instance.respond_to?(:available?) && !instance.available?
            tool_name = instance.respond_to?(:name) ? instance.name : klass.name
            warn "Info: Tool '#{tool_name}' is not available, skipping"
            next false
          end
          true
        rescue ArgumentError, LoadError, StandardError
          false
        end
      end
    end

    # Activate a gem that isn't yet active by asking RubyGems to activate it.
    # This adds its lib paths to $LOAD_PATH AND activates its dependencies,
    # unlike a manual $LOAD_PATH manipulation which would leave deps unresolved.
    def activate_unbundled_gem(name)
      gem name
      true
    rescue Gem::MissingSpecError, Gem::LoadError
      false
    end

    # Eagerly load tool classes from any required gem that uses lazy loading
    # (e.g. Zeitwerk). Calls .load_all_tools on every module that responds to it,
    # so any gem following that convention works — not just SharedTools.
    def eager_load_gem_tools
      ObjectSpace.each_object(Module) do |mod|
        mod.load_all_tools if mod.respond_to?(:load_all_tools)
      rescue StandardError
        next
      end
    rescue StandardError => e
      warn "Warning: Failed to eager-load gem tools: #{e.message}"
    end
  end
end
