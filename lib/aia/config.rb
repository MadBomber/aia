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

module AIA
  # Backward compatibility alias
  ConfigSection = MywayConfig::ConfigSection

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
    attr_config :service, :llm, :prompts, :output, :audio, :image, :embedding,
                :tools, :flags, :registry, :paths, :logger, :rules, :concurrency

    # Array/collection attributes
    attr_config :models, :pipeline, :require_libs, :mcp_servers, :mcp_use, :mcp_skip, :context_files

    # Runtime attributes (not loaded from config files)
    attr_accessor :prompt_id, :stdin_content, :remaining_args, :dump_file,
                  :completion, :mcp_list, :list_tools,
                  :executable_prompt_content,
                  :tool_names, :loaded_tools,
                  :log_level_override, :log_file_override,
                  :connected_mcp_servers,  # Array of successfully connected MCP server names
                  :mcp_server_tool_counts, # Hash of name => tool_count for connected MCP servers
                  :failed_mcp_servers      # Array of {name:, error:} hashes for failed MCP servers

    # ==========================================================================
    # Type Coercion
    # ==========================================================================

    # Convert array of hashes to array of ModelSpec objects
    TO_MODEL_SPECS = ->(v) {
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
      output: config_section_coercion(:output),
      audio: config_section_coercion(:audio),
      image: config_section_coercion(:image),
      embedding: config_section_coercion(:embedding),
      tools: config_section_coercion(:tools),
      flags: config_section_coercion(:flags),
      logger: config_section_coercion(:logger),
      registry: config_section_coercion(:registry),
      paths: config_section_coercion(:paths),
      rules: config_section_coercion(:rules),
      concurrency: config_section_coercion(:concurrency),

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
      chat: [:flags, :chat],
      cost: [:flags, :cost],
      fuzzy: [:flags, :fuzzy],
      tokens: [:flags, :tokens],
      no_mcp: [:flags, :no_mcp],
      debug: [:flags, :debug],
      verbose: [:flags, :verbose],
      consensus: [:flags, :consensus],
      track_pipeline: [:flags, :track_pipeline],
      expert_routing: [:flags, :expert_routing],
      tool_filter_a: [:flags, :tool_filter_a],
      tool_filter_b: [:flags, :tool_filter_b],
      tool_filter_c: [:flags, :tool_filter_c],
      tool_filter_d: [:flags, :tool_filter_d],
      tool_filter_load: [:flags, :tool_filter_load],
      tool_filter_save: [:flags, :tool_filter_save],
      concurrent_auto: [:concurrency, :auto],
      # llm section
      temperature: [:llm, :temperature],
      max_tokens: [:llm, :max_tokens],
      top_p: [:llm, :top_p],
      frequency_penalty: [:llm, :frequency_penalty],
      presence_penalty: [:llm, :presence_penalty],
      # prompts section
      prompts_dir: [:prompts, :dir],
      roles_prefix: [:prompts, :roles_prefix],
      role: [:prompts, :role],
      system_prompt: [:prompts, :system_prompt],
      # output section
      output: [:output, :file],
      history_file: [:output, :history_file],
      append: [:output, :append],
      markdown: [:output, :markdown],
      # audio section (speak is a flag, not audio config)
      speak: [:flags, :speak],
      voice: [:audio, :voice],
      speech_model: [:audio, :speech_model],
      transcription_model: [:audio, :transcription_model],
      # image section
      image_size: [:image, :size],
      image_quality: [:image, :quality],
      image_style: [:image, :style],
      # tools section
      tool_paths: [:tools, :paths],
      allowed_tools: [:tools, :allowed],
      rejected_tools: [:tools, :rejected],
      # registry section
      refresh: [:registry, :refresh],
      # rules section
      rules_enabled: [:rules, :enabled],
    }.freeze

    def initialize(overrides: {})
      super()

      # Load extra config file AFTER base init (defaults + user config + env vars)
      # but BEFORE CLI overrides, so CLI flags take precedence.
      extra_config_path = overrides.delete(:extra_config_file)
      load_extra_config(extra_config_path) if extra_config_path

      apply_models_env_var unless overrides[:models]
      apply_overrides(overrides) if overrides && !overrides.empty?
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

    # Convert config to hash (for dump, etc.)
    def to_h
      {
        service: service.to_h,
        llm: llm.to_h,
        models: models.map(&:to_h),
        prompts: prompts.to_h,
        output: output.to_h,
        audio: audio.to_h,
        image: image.to_h,
        embedding: embedding.to_h,
        tools: tools.to_h,
        flags: flags.to_h,
        logger: logger.to_h,
        registry: registry.to_h,
        paths: paths.to_h,
        rules: rules.to_h,
        concurrency: concurrency.to_h,
        pipeline: pipeline,
        require_libs: require_libs,
        mcp_servers: mcp_servers,
        mcp_use: mcp_use,
        mcp_skip: mcp_skip,
        context_files: context_files
      }
    end

    private

    # Load a config file that REPLACES the user's personal config.
    def load_extra_config(path)
      path = File.expand_path(path)

      unless File.exist?(path)
        warn "ERROR: Config file not found: #{path}"
        exit 1
        return
      end

      reset_to_defaults

      raw = YAML.safe_load(
        File.read(path),
        permitted_classes: [Symbol],
        symbolize_names: true,
        aliases: true
      ) || {}

      config_hash = raw.key?(:defaults) ? (raw[:defaults] || {}) : raw

      paths[:extra_config_file] = path

      config_hash.each do |key, value|
        case key
        when :models
          self.models = TO_MODEL_SPECS.call(Array(value))
        when :pipeline, :require_libs, :context_files, :mcp_use, :mcp_skip
          send("#{key}=", Array(value)) if respond_to?("#{key}=")
        when :mcp_servers
          self.mcp_servers = Array(value)
        when :service, :llm, :prompts, :output, :audio, :image, :embedding,
             :tools, :flags, :registry, :paths, :logger, :rules, :concurrency
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

    def apply_models_env_var
      models_env = ENV['AIA_MODEL']
      return if models_env.nil? || models_env.empty?

      self.models = TO_MODEL_SPECS.call(models_env.split(',').map(&:strip))
    end

    def expand_paths
      paths.aia_dir = File.expand_path(paths.aia_dir) if paths.aia_dir
      paths.config_file = File.expand_path(paths.config_file) if paths.config_file
      prompts.dir = File.expand_path(prompts.dir) if prompts.dir
      prompts.roles_dir = File.expand_path(prompts.roles_dir) if prompts.roles_dir
      output.history_file = File.expand_path(output.history_file) if output.history_file
      rules.dir = File.expand_path(rules.dir) if rules.respond_to?(:dir) && rules.dir
    end

    def ensure_arrays
      self.pipeline = [] if pipeline.nil?
      self.require_libs = [] if require_libs.nil?
      self.context_files = [] if context_files.nil?
      self.mcp_servers = [] if mcp_servers.nil?
      self.mcp_use = [] if mcp_use.nil?
      self.mcp_skip = [] if mcp_skip.nil?
      tools.paths = [] if tools.paths.nil?
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
