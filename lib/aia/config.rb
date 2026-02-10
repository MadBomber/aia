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
#   defaults → config file → CLI arguments → embedded directives

require 'myway_config'
require 'yaml'
require 'date'

require_relative 'config/model_spec'
require_relative 'config/mcp_parser'

module AIA
  # Backward compatibility alias — existing code and tests reference AIA::ConfigSection
  ConfigSection = MywayConfig::ConfigSection

  class Config < MywayConfig::Base
    config_name :aia
    env_prefix :aia
    defaults_path File.expand_path('config/defaults.yml', __dir__)

    # AIA is a CLI tool, not a Rails app — no environment sections needed.
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
                :tools, :flags, :registry, :paths, :logger

    # Array/collection attributes
    attr_config :models, :pipeline, :require_libs, :mcp_servers, :mcp_use, :mcp_skip, :context_files

    # Runtime attributes (not loaded from config files)
    attr_accessor :prompt_id, :stdin_content, :remaining_args, :dump_file,
                  :completion, :mcp_list, :list_tools, :executable_prompt,
                  :executable_prompt_file, :executable_prompt_content,
                  :tool_names, :loaded_tools,
                  :log_level_override, :log_file_override,
                  :connected_mcp_servers, # Array of successfully connected MCP server names
                  :failed_mcp_servers     # Array of {name:, error:} hashes for failed MCP servers

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
      registry: config_section_coercion(:registry),
      paths: config_section_coercion(:paths),

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
      terse: [:flags, :terse],
      debug: [:flags, :debug],
      verbose: [:flags, :verbose],
      consensus: [:flags, :consensus],
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
      parameter_regex: [:prompts, :parameter_regex],
      system_prompt: [:prompts, :system_prompt],
      # output section
      output: [:output, :file],
      history_file: [:output, :history_file],
      append: [:output, :append],
      markdown: [:output, :markdown],
      # audio section
      speak: [:audio, :speak],
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
        registry: registry.to_h,
        paths: paths.to_h,
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
    # Resets all values to bundled defaults first, then applies the
    # file's values on top. This means -c gives you a clean slate
    # based on defaults + the specified file only.
    #
    # Uses the same YAML structure as defaults.yml (nested sections).
    # Supports both flat format and wrapped (defaults:) format.
    #
    # @param path [String] path to the YAML config file
    def load_extra_config(path)
      path = File.expand_path(path)

      unless File.exist?(path)
        warn "ERROR: Config file not found: #{path}"
        exit 1
        return # guard for test environments that override exit
      end

      # Reset everything to bundled defaults so the user's personal
      # config (~/.config/aia/aia.yml) does not bleed through.
      reset_to_defaults

      raw = YAML.safe_load(
        File.read(path),
        permitted_classes: [Symbol],
        symbolize_names: true,
        aliases: true
      ) || {}

      config_hash = raw.key?(:defaults) ? (raw[:defaults] || {}) : raw

      # Store the path for reference (visible in --dump output)
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
             :tools, :flags, :registry, :paths, :logger
          section = send(key)
          if section.is_a?(MywayConfig::ConfigSection) && value.is_a?(Hash)
            merge_into_section(section, value)
          end
        end
      end

      expand_paths
    end

    # Reset all configuration values to the bundled defaults from
    # defaults.yml, discarding anything set by the user's personal
    # config file or environment variables.
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

    # Recursively reset a ConfigSection to match the given defaults hash.
    #
    # @param section [MywayConfig::ConfigSection] target section
    # @param defaults_hash [Hash] default values to restore
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

    # Recursively merge a hash into a ConfigSection, preserving
    # existing values for keys not present in the hash.
    #
    # @param section [MywayConfig::ConfigSection] target section
    # @param hash [Hash] values to merge in
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

    # Apply AIA_MODEL env var if set (supports comma-separated models with optional roles)
    # Format: MODEL[=ROLE][,MODEL[=ROLE]]...
    def apply_models_env_var
      models_env = ENV['AIA_MODEL']
      return if models_env.nil? || models_env.empty?

      self.models = TO_MODEL_SPECS.call(models_env.split(',').map(&:strip))
    end

    def expand_paths
      # Expand ~ in paths
      if paths.aia_dir
        paths.aia_dir = File.expand_path(paths.aia_dir)
      end

      if paths.config_file
        paths.config_file = File.expand_path(paths.config_file)
      end

      if prompts.dir
        prompts.dir = File.expand_path(prompts.dir)
      end

      if prompts.roles_dir
        prompts.roles_dir = File.expand_path(prompts.roles_dir)
      end

      if output.history_file
        output.history_file = File.expand_path(output.history_file)
      end
    end

    def ensure_arrays
      # Ensure array fields are actually arrays
      self.pipeline = [] if pipeline.nil?
      self.require_libs = [] if require_libs.nil?
      self.context_files = [] if context_files.nil?
      self.mcp_servers = [] if mcp_servers.nil?
      self.mcp_use = [] if mcp_use.nil?
      self.mcp_skip = [] if mcp_skip.nil?

      # Ensure tools.paths is an array
      tools.paths = [] if tools.paths.nil?
    end

    # Process MCP JSON files and merge servers into mcp_servers
    #
    # @param mcp_files [Array<String>] paths to MCP JSON configuration files
    def process_mcp_files(mcp_files)
      return if mcp_files.nil? || mcp_files.empty?

      servers_from_files = McpParser.parse_files(mcp_files)
      return if servers_from_files.empty?

      # Merge with existing mcp_servers (CLI files take precedence)
      self.mcp_servers = (mcp_servers || []) + servers_from_files
    end

    def apply_nested_override(parts, value)
      section = parts[0].to_sym
      key = parts[1].to_sym

      case section
      when :llm
        llm.send("#{key}=", value) if llm.respond_to?("#{key}=")
      when :prompts
        prompts.send("#{key}=", value) if prompts.respond_to?("#{key}=")
      when :output
        output.send("#{key}=", value) if output.respond_to?("#{key}=")
      when :audio
        audio.send("#{key}=", value) if audio.respond_to?("#{key}=")
      when :image
        image.send("#{key}=", value) if image.respond_to?("#{key}=")
      when :embedding
        embedding.send("#{key}=", value) if embedding.respond_to?("#{key}=")
      when :tools
        tools.send("#{key}=", value) if tools.respond_to?("#{key}=")
      when :flags
        flags.send("#{key}=", value) if flags.respond_to?("#{key}=")
      when :registry
        registry.send("#{key}=", value) if registry.respond_to?("#{key}=")
      when :paths
        paths.send("#{key}=", value) if paths.respond_to?("#{key}=")
      end
    end
  end
end
