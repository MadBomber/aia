# frozen_string_literal: true

# lib/aia/config.rb
#
# AIA Configuration using MywayConfig
#
# Schema is defined in lib/aia/config/defaults.yml (single source of truth)
# Configuration uses nested sections for better organization:
#   - AIA.config.llm.temperature
#   - AIA.config.prompts.dir
#   - AIA.config.models.first.name
#
# Configuration sources (lowest to highest priority):
# 1. Bundled defaults: lib/aia/config/defaults.yml (ships with gem)
# 2. User config: ~/.config/aia/aia.yml (XDG)
# 3. Environment variables (AIA_*)
# 4. CLI arguments (applied via overrides)
# 5. Embedded directives (/config)
#
# When -c / --config-file is used, it REPLACES sources 2 and 3:
#   defaults -> config file -> CLI arguments -> embedded directives

require 'myway_config'
require 'yaml'
require 'date'

require_relative 'config/model_spec'
require_relative 'config/mcp_parser'
require_relative 'config/value_caster'

module AIA
  class Config < MywayConfig::Base
    config_name :aia
    env_prefix :aia
    defaults_path File.expand_path('config/defaults.yml', __dir__)

    # AIA is a CLI tool, not a Rails app -- no environment sections needed.
    class << self
      def validate_environment!
        # no-op: AIA has no environment sections in defaults.yml
      end
    end

    # ==========================================================================
    # Schema Definition (loaded from defaults.yml via MywayConfig)
    # ==========================================================================

    # Nested section attributes (defined as hashes, converted to ConfigSection)
    SECTIONS = %i[service llm prompts skills output audio image
                  tools flags registry paths logger concurrency tool_filter].freeze

    attr_config(*SECTIONS)

    # Array/collection attributes
    attr_config :models, :pipeline, :require_libs, :mcp_servers, :mcp_use, :mcp_skip, :context_files

    # Model switching: /model history transfer mode and model-name aliases
    attr_config :model_switch_history, :model_aliases

    # Runtime attributes (not loaded from config files)
    attr_accessor :provider # --provider: default provider for prefixless models; also scopes --list-models
    attr_accessor :prompt_id, :stdin_content, :remaining_args, :dump_file,
                  :completion, :mcp_list, :list_tools, :list_skills, :list_roles,
                  :executable_prompt_content,
                  :tool_names, :loaded_tools, :loaded_plugins,
                  :log_level_override, :log_file_override,
                  :connected_mcp_servers,  # Array of successfully connected MCP server names
                  :mcp_server_tool_counts, # Hash of name => tool_count for connected MCP servers
                  :failed_mcp_servers      # Array of {name:, error:} hashes for failed MCP servers

    # ==========================================================================
    # Type Coercion
    # ==========================================================================

    # Convert array of hashes to array of ModelSpec objects
    TO_MODEL_SPECS = lambda { |v|
      return [] if v.nil?
      return v if v.is_a?(Array) && v.first.is_a?(ModelSpec)

      model_counts = Hash.new(0)

      Array(v).map do |spec|
        # Handle string format from CLI
        if spec.is_a?(String)
          if spec.include?('=')
            name, role = spec.split('=', 2)
            spec = { name: name.strip, role: role.strip }
          else
            spec = { name: spec.strip }
          end
        end

        spec = spec.transform_keys(&:to_sym) if spec.respond_to?(:transform_keys)
        name = spec[:name]

        model_counts[name] += 1
        instance = model_counts[name]

        ModelSpec.new(
          name: name,
          role: spec[:role],
          instance: instance,
          internal_id: instance > 1 ? "#{name}##{instance}" : name
        )
      end
    }

    coerce_types(
      # Nested sections -> ConfigSection objects (with schema defaults merged)
      service: config_section_coercion(:service),
      llm: config_section_coercion(:llm),
      prompts: config_section_coercion(:prompts),
      skills: config_section_coercion(:skills),
      output: config_section_coercion(:output),
      audio: config_section_coercion(:audio),
      image: config_section_coercion(:image),
      tools: config_section_coercion(:tools),
      flags: config_section_coercion(:flags),
      logger: config_section_coercion(:logger),
      registry: config_section_coercion(:registry),
      paths: config_section_coercion(:paths),
      concurrency: config_section_coercion(:concurrency),
      tool_filter: config_section_coercion(:tool_filter),

      # Arrays
      models: TO_MODEL_SPECS,
      pipeline: { type: :string, array: true },
      require_libs: { type: :string, array: true },
      context_files: { type: :string, array: true },
      mcp_use: { type: :string, array: true },
      mcp_skip: { type: :string, array: true }
    )

    # ==========================================================================
    # Callbacks
    # ==========================================================================

    on_load :expand_paths, :ensure_arrays

    # ==========================================================================
    # Class Methods
    # ==========================================================================

    class << self
      # Setup configuration with CLI overrides
      #
      # @param cli_overrides [Hash] overrides from CLI parsing
      # @return [Config] configured instance
      def setup(cli_overrides = {})
        new(overrides: cli_overrides)
      end
    end

    # ==========================================================================
    # Instance Methods
    # ==========================================================================

    # Mapping of flat CLI keys to their nested config locations
    CLI_TO_NESTED_MAP = {
      # flags section
      chat: %i[flags chat],
      cost: %i[flags cost],
      fuzzy: %i[flags fuzzy],
      tokens: %i[flags tokens],
      no_mcp: %i[flags no_mcp],
      debug: %i[flags debug],
      verbose: %i[flags verbose],
      consensus: %i[flags consensus],
      track_pipeline: %i[flags track_pipeline],
      auto_tool_filter: %i[flags auto_tool_filter],
      allow_ruby_eval: %i[flags allow_ruby_eval],
      thinking: %i[flags thinking],
      tool_filter_timeout_s: %i[tool_filter timeout_s],
      concurrent_auto: %i[concurrency auto],
      # llm section
      temperature: %i[llm temperature],
      max_tokens: %i[llm max_tokens],
      top_p: %i[llm top_p],
      frequency_penalty: %i[llm frequency_penalty],
      presence_penalty: %i[llm presence_penalty],
      # prompts section
      prompts_dir: %i[prompts dir],
      roles_prefix: %i[prompts roles_prefix],
      role: %i[prompts role],
      skills_dir: %i[skills dir],
      skills: %i[prompts skills],
      system_prompt: %i[prompts system_prompt],
      # output section
      output: %i[output file],
      history_file: %i[output history_file],
      append: %i[output append],
      # audio section (speak is a flag, not audio config)
      speak: %i[flags speak],
      voice: %i[audio voice],
      speak_command: %i[audio speak_command],
      speech_model: %i[audio speech_model],
      transcription_model: %i[audio transcription_model],
      # image section
      paint: %i[flags paint],
      image_model: %i[image model],
      image_size: %i[image size],
      image_quality: %i[image quality],
      image_style: %i[image style],
      # tools section
      tool_paths: %i[tools paths],
      allowed_tools: %i[tools allowed],
      rejected_tools: %i[tools rejected],
      tool_approval: %i[tools approval],
      # registry section
      refresh: %i[registry refresh],
      # paths section
      plugins_dir: %i[paths plugins_dir]
    }.freeze

    def initialize(overrides: {})
      super()

      # Load extra config file AFTER base init (defaults + user config + env vars)
      # but BEFORE CLI overrides, so CLI flags take precedence.
      extra_config_path = overrides.delete(:extra_config_file)
      load_extra_config(extra_config_path) if extra_config_path

      drop_unknown_keys
      # Not a schema key, so it is set after unknown keys are dropped
      paths[:extra_config_file] = File.expand_path(extra_config_path) if extra_config_path && File.exist?(extra_config_path)
      cast_string_values
      apply_models_env_var unless overrides[:models]
      apply_plugins_dir_env_var unless overrides[:plugins_dir]
      apply_overrides(overrides) if overrides && !overrides.empty?
      apply_cli_provider(overrides.key?(:models) ? :fill : :replace)
      expand_paths
      process_mcp_files(overrides[:mcp_files]) if overrides[:mcp_files]
    end

    # Apply CLI or runtime overrides to configuration
    #
    # @param overrides [Hash] key-value pairs to override
    def apply_overrides(overrides)
      overrides.each do |key, value|
        key_sym = key.to_sym

        # Check if this is a flat CLI key that maps to a nested location
        if CLI_TO_NESTED_MAP.key?(key_sym)
          section, nested_key = CLI_TO_NESTED_MAP[key_sym]
          section_obj = send(section)
          section_obj.send("#{nested_key}=", value) if section_obj.respond_to?("#{nested_key}=")
        elsif key_sym == :models
          self.models = TO_MODEL_SPECS.call(Array(value))
        elsif respond_to?("#{key}=")
          send("#{key}=", value)
        elsif key.to_s.include?('__')
          # Handle nested keys like 'llm__temperature'
          parts = key.to_s.split('__')
          apply_nested_override(parts, value)
        end
      end
    end

    # +hash+ without the keys +schema+ doesn't define, at every level. A
    # schema value that is an empty Hash accepts any keys.
    #
    # @param hash [Hash] section values (from defaults, config files and env)
    # @param schema [Hash] the section's defaults from defaults.yml
    # @return [Hash]
    def self.schema_keys_only(hash, schema)
      return hash if schema.empty?

      hash.each_with_object({}) do |(key, value), kept|
        next unless schema.key?(key)

        sub = schema[key]
        kept[key] = sub.is_a?(Hash) && value.is_a?(Hash) ? schema_keys_only(value, sub) : value
      end
    end

    # Convert config to hash (for dump, etc.)
    def to_h
      SECTIONS.to_h { [it, send(it).to_h] }.merge(
        models: models.map(&:to_h),
        model_switch_history:, model_aliases:,
        pipeline:, require_libs:, mcp_servers:, mcp_use:, mcp_skip:, context_files:
      )
    end

    private

    # Keys that defaults.yml doesn't define — removed settings in an old
    # config file, or AIA_* variables for them — are ignored, so they
    # don't linger in the config or in --dump.
    def drop_unknown_keys
      SECTIONS.each do |name|
        section = send(name)
        kept = self.class.schema_keys_only(section.to_h, self.class.schema[name] || {})
        send(:"#{name}=", MywayConfig::ConfigSection.new(kept)) unless kept == section.to_h
      end
    end

    # Environment variables arrive as strings; give each section value the
    # type of its default (booleans, numbers, comma-separated lists).
    def cast_string_values
      SECTIONS.each do |name|
        ValueCaster.cast_section!(send(name), self.class.schema[name] || {}, name.to_s)
      end
    end

    # Load a config file that REPLACES the user's personal config.
    # :reek:TooManyStatements -- single case dispatch mapping YAML keys to typed config setters; one branch per key family
    # :reek:DuplicateMethodCall -- Array(value) sits in mutually exclusive case branches; hoisting it would coerce hash-section values too
    def load_extra_config(path)
      path = File.expand_path(path)

      unless File.exist?(path)
        $stderr.puts "ERROR: Config file not found: #{path}"
        exit 1
        return # rubocop:disable Lint/UnreachableCode -- exit is mocked in tests
      end

      reset_to_defaults

      raw = YAML.safe_load_file(path, permitted_classes: [Symbol],
        symbolize_names: true,
        aliases: true) || {}

      config_hash = raw.key?(:defaults) ? (raw[:defaults] || {}) : raw

      config_hash.each do |key, value|
        case key
        when :models
          self.models = TO_MODEL_SPECS.call(Array(value))
        when :pipeline, :require_libs, :context_files, :mcp_use, :mcp_skip
          send("#{key}=", Array(value)) if respond_to?("#{key}=")
        when :mcp_servers
          self.mcp_servers = Array(value)
        when :model_switch_history, :model_aliases
          send("#{key}=", value)
        when *SECTIONS
          section = send(key)
          if section.is_a?(MywayConfig::ConfigSection) && value.is_a?(Hash)
            merge_into_section(section, value)
          end
        end
      end

      expand_paths
    end

    def reset_to_defaults
      defaults = self.class.schema

      defaults.each do |key, value|
        section = respond_to?(key) ? send(key) : nil

        if section.is_a?(MywayConfig::ConfigSection) && value.is_a?(Hash)
          reset_section(section, value)
        elsif key == :models
          self.models = TO_MODEL_SPECS.call(Array(value))
        elsif respond_to?("#{key}=")
          send("#{key}=", value)
        end
      end
    end

    def reset_section(section, defaults_hash)
      defaults_hash.each do |key, value|
        existing = section[key.to_sym]
        if existing.is_a?(MywayConfig::ConfigSection) && value.is_a?(Hash)
          reset_section(existing, value)
        else
          section[key.to_sym] = value
        end
      end
    end

    def merge_into_section(section, hash)
      hash.each do |key, value|
        existing = section[key.to_sym]
        if existing.is_a?(MywayConfig::ConfigSection) && value.is_a?(Hash)
          merge_into_section(existing, value)
        else
          section[key.to_sym] = value
        end
      end
    end

    # `--provider SLUG` on the command line. Given together with --model
    # (+mode+ :fill), it is the provider for the models named there without
    # a "<provider>/" prefix; an explicit prefix keeps its own provider,
    # since both values come from the command line. Given without --model
    # (+mode+ :replace), the models from AIA_MODEL or the config file keep
    # their names but take this provider, prefix or not, because a
    # command-line flag outranks both.
    #
    # @param mode [Symbol] :fill or :replace
    def apply_cli_provider(mode)
      return if provider.nil? || provider.to_s.empty?

      Array(models).each do |spec|
        next unless spec.respond_to?(:provider)

        spec.provider = provider if mode == :replace || spec.provider.nil?
      end
    end

    def apply_models_env_var
      models_env = ENV.fetch('AIA_MODEL', nil)
      return if models_env.nil? || models_env.empty?

      self.models = TO_MODEL_SPECS.call(models_env.split(',').map(&:strip))
    end

    # Backward-compatible top-level env var for plugin directory.
    # Unlike most nested config values, this uses AIA_PLUGINS_DIR per requirements.
    def apply_plugins_dir_env_var
      plugins_dir_env = ENV.fetch('AIA_PLUGINS_DIR', nil)
      return if plugins_dir_env.nil? || plugins_dir_env.empty?

      paths.plugins_dir = plugins_dir_env
    end

    def expand_paths
      expand_path_on(paths, :aia_dir)
      expand_path_on(paths, :plugins_dir)
      expand_path_on(prompts, :dir)
      expand_path_on(skills, :dir)
      expand_path_on(output, :history_file)
    end

    def expand_path_on(obj, method_name)
      return unless obj.respond_to?(method_name)
      val = obj.send(method_name)
      return unless val
      obj.send(:"#{method_name}=", File.expand_path(val))
    end

    def ensure_arrays
      self.pipeline = [] if pipeline.nil?
      self.require_libs = [] if require_libs.nil?
      self.context_files = [] if context_files.nil?
      self.mcp_servers = [] if mcp_servers.nil?
      self.mcp_use = [] if mcp_use.nil?
      self.mcp_skip = [] if mcp_skip.nil?
      tools.paths = [] if tools.paths.nil?
      prompts.skills = [] if prompts.respond_to?(:skills) && prompts.skills.nil?
    end

    def process_mcp_files(mcp_files)
      return if mcp_files.nil? || mcp_files.empty?

      servers_from_files = McpParser.parse_files(mcp_files)
      return if servers_from_files.empty?

      self.mcp_servers = (mcp_servers || []) + servers_from_files
    end

    def apply_nested_override(parts, value)
      section = parts[0].to_sym
      key = parts[1].to_sym

      target = respond_to?(section) ? send(section) : nil
      return unless target.respond_to?("#{key}=")

      target.send("#{key}=", value)
    end
  end
end
