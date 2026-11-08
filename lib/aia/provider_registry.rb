# lib/aia/provider_registry.rb
#
# Generic gateway to RubyLLM's provider registry (ruby_llm >= 2.0).
# AIA hardcodes no provider names: a model prefix counts as a provider
# exactly when RubyLLM has it registered — built-in providers, provider gems
# the user loaded (e.g. `aia --require ruby_llm-providers-xyzzy`), or a gem
# following the conventional `ruby_llm/providers/<slug>` require path that
# can be loaded on demand the first time its slug is seen.

module AIA
  module ProviderRegistry
    module_function

    # All registered provider slugs, as strings.
    def slugs
      RubyLLM::Provider.providers.keys.map(&:to_s)
    end

    # Registered providers as {slug (String) => provider class}.
    def providers
      RubyLLM::Provider.providers.transform_keys(&:to_s)
    end

    # True when RubyLLM already has this slug registered.
    def registered?(slug)
      return false unless slug

      RubyLLM::Provider.providers.key?(slug.to_sym)
    end

    # True when the slug names a registered provider, loading the
    # conventional provider gem on demand the first time it is seen.
    def available?(slug)
      registered?(slug) || load(slug)
    end

    # Attempt to require the conventional gem path for a provider slug.
    # Returns true when the provider ends up registered. Failed lookups are
    # cached so repeated non-provider prefixes (model ids also use "/")
    # don't pay the require cost every time. When the plain require fails
    # because aia runs under Bundler and the gem is installed but not in the
    # Gemfile, the gem is sideloaded from the RubyGems search path.
    def load(slug)
      slug = slug.to_s
      return false unless slug.match?(/\A[a-z0-9_]+\z/)

      @load_attempts ||= {}
      return @load_attempts[slug] if @load_attempts.key?(slug)

      @load_attempts[slug] =
        begin
          require "ruby_llm/providers/#{slug}"
          registered?(slug)
        rescue LoadError
          sideload(slug)
        end
    end

    # Load an installed `ruby_llm-providers-<slug>` gem that the active
    # bundle hides. Under Bundler only the Gemfile's gems can be required,
    # so a provider gem added with `gem install` is invisible to a plain
    # require even though it sits on disk. This finds its gemspec on the
    # RubyGems search path and, when every runtime dependency it declares is
    # already satisfied by the bundle, adds its lib directory to the load
    # path and requires it. The bundle itself is not changed. Returns true
    # when the provider ends up registered.
    def sideload(slug)
      spec = installed_spec(slug)
      return false unless spec

      unmet = spec.runtime_dependencies.reject { |dep| dependency_met?(dep) }
      unless unmet.empty?
        AIA.debug_warn("#{spec.full_name} is installed but needs #{unmet.join(', ')}, which this bundle does not provide")
        return false
      end

      spec.full_require_paths.each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }
      require "ruby_llm/providers/#{slug}"
      registered?(slug)
    rescue LoadError
      false
    end

    # The newest installed gemspec for `ruby_llm-providers-<slug>`, read from
    # the specifications directories on the RubyGems search path, or nil.
    # Reads the files directly, so it sees gems the bundle does not.
    def installed_spec(slug)
      name = "ruby_llm-providers-#{slug}"
      Gem.path
         .flat_map { |dir| Dir[File.join(dir, 'specifications', "#{name}-*.gemspec")] }
         .filter_map { |file| Gem::Specification.load(file) }
         .select { |spec| spec.name == name }
         .max_by(&:version)
    end

    # Whether a gem dependency is satisfied by a gem already active in this
    # process (under Bundler, that is the bundle).
    def dependency_met?(dep)
      active = Gem.loaded_specs[dep.name]
      !active.nil? && dep.requirement.satisfied_by?(active.version)
    end

    # A provider instance ready for API calls (model listing etc.).
    # Raises RubyLLM's own errors for unknown or unconfigured providers.
    def instantiate(slug)
      RubyLLM::Provider.resolve!(slug.to_sym).new(RubyLLM.config)
    end

    # Slugs of conventionally named provider gems (ruby_llm-providers-<slug>)
    # that are installed, whether in the bundle or only on the RubyGems
    # search path, and whether or not they are loaded yet.
    def installed_gem_slugs
      prefix = 'ruby_llm-providers-'
      bundled = Gem::Specification.map(&:name)
      on_disk = Gem.path.flat_map { |dir| Dir[File.join(dir, 'specifications', "#{prefix}*.gemspec")] }
                   .map { |file| File.basename(file, '.gemspec').sub(/-[^-]+\z/, '') }
      (bundled + on_disk).select { |name| name.start_with?(prefix) }
                         .map { |name| name.delete_prefix(prefix) }
                         .uniq
    end

    # Register every installed conventional provider gem, so a full listing
    # reflects what is available, not just what has been referenced so far.
    def load_installed_gems
      installed_gem_slugs.each { |slug| load(slug) }
    end

    # Endpoints for local servers that RubyLLM leaves unset, so they work
    # without an environment variable when running on their usual port.
    DEFAULT_ENDPOINTS = { 'ollama' => 'http://localhost:11434/v1' }.freeze

    # Generic env-var endpoint overrides: for every registered provider,
    # <SLUG>_API_BASE sets RubyLLM.config.<slug>_api_base when the provider
    # defines that option (RubyLLM registers the accessor with the provider).
    # A provider in DEFAULT_ENDPOINTS with no endpoint set gets its default.
    def apply_env_endpoints
      RubyLLM.configure do |c|
        slugs.each do |slug|
          setter = :"#{slug}_api_base="
          next unless c.respond_to?(setter)

          value = ENV.fetch("#{slug.upcase}_API_BASE", nil) || default_endpoint(c, slug)
          c.public_send(setter, value) if value
        end
      end
    end

    # The default endpoint for +slug+ when RubyLLM has none configured.
    def default_endpoint(ruby_llm_config, slug)
      getter = :"#{slug}_api_base"
      return nil if ruby_llm_config.respond_to?(getter) && ruby_llm_config.public_send(getter)

      DEFAULT_ENDPOINTS[slug.to_s]
    end
  end
end
