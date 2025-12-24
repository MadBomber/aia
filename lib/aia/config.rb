# frozen_string_literal: true

# lib/aia/config.rb
#
# AIA Configuration using Anyway Config
#
# Schema is defined in lib/aia/config/defaults.yml (single source of truth)
# Configuration uses nested sections for better organization:
#   - AIA.config.llm.temperature
#   - AIA.config.prompts.dir
#   - AIA.config.models.first.name
#
# Configuration sources (lowest to highest priority):
# 1. Bundled defaults: lib/aia/config/defaults.yml (ships with gem)
# 2. User config: ~/.aia/config.yml
# 3. Environment variables (AIA_*)
# 4. CLI arguments (applied via overrides)
# 5. Embedded directives (//config)

require 'anyway_config'
require 'yaml'
require 'date'

require_relative 'config/config_section'
require_relative 'config/model_spec'
require_relative 'config/defaults_loader'

module AIA
  class Config < Anyway::Config
    config_name :aia
    env_prefix :aia

    # ==========================================================================
    # Schema Definition (loaded from defaults.yml - single source of truth)
    # ==========================================================================

    DEFAULTS_PATH = File.expand_path('config/defaults.yml', __dir__).freeze
    SCHEMA = Loaders::DefaultsLoader.schema

    # Nested section attributes (defined as hashes, converted to ConfigSection)
    attr_config :service, :llm, :prompts, :output, :audio, :image, :embedding,
                :tools, :flags, :registry, :paths, :logger

    # Array/collection attributes
    attr_config :models, :pipeline, :require_libs, :mcp_servers, :context_files

    # Runtime attributes (not loaded from config files)
    attr_accessor :prompt_id, :stdin_content, :remaining_args, :dump_file,
                  :completion, :show_metrics, :show_cost, :executable_prompt,
                  :executable_prompt_file, :tool_names, :loaded_tools, :next_prompt

    # Alias for next prompt (for backward compatibility with directives)
    def next
      @next_prompt
    end

    def next=(value)
      @next_prompt = value
      # Also prepend to pipeline
      pipeline.unshift(value) if value && !value.empty?
    end

    # ==========================================================================
    # Type Coercion
    # ==========================================================================

    # Create a coercion that merges incoming value with SCHEMA defaults for a section
    def self.config_section_with_defaults(section_key)
      defaults = SCHEMA[section_key] || {}
      ->(v) {
        return v if v.is_a?(ConfigSection)
        incoming = v || {}
        merged = deep_merge_hashes(defaults.dup, incoming)
        ConfigSection.new(merged)
      }
    end

    # Deep merge helper for coercion
    def self.deep_merge_hashes(base, overlay)
      base.merge(overlay || {}) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_hashes(old_val, new_val)
        else
          new_val.nil? ? old_val : new_val
        end
      end
    end

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
      # Nested sections -> ConfigSection objects (with SCHEMA defaults merged)
      service: config_section_with_defaults(:service),
      llm: config_section_with_defaults(:llm),
      prompts: config_section_with_defaults(:prompts),
      output: config_section_with_defaults(:output),
      audio: config_section_with_defaults(:audio),
      image: config_section_with_defaults(:image),
      embedding: config_section_with_defaults(:embedding),
      tools: config_section_with_defaults(:tools),
      flags: config_section_with_defaults(:flags),
      registry: config_section_with_defaults(:registry),
      paths: config_section_with_defaults(:paths),

      # Arrays
      models: TO_MODEL_SPECS,
      pipeline: { type: :string, array: true },
      require_libs: { type: :string, array: true },
      context_files: { type: :string, array: true }
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
      fuzzy: [:flags, :fuzzy],
      terse: [:flags, :terse],
      debug: [:flags, :debug],
      verbose: [:flags, :verbose],
      consensus: [:flags, :consensus],
      # llm section
      adapter: [:llm, :adapter],
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
      out_file: [:output, :file],
      log_file: [:output, :log_file],
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
      # paths section
      extra_config_file: [:paths, :extra_config_file]
    }.freeze

    def initialize(overrides: {})
      super()
      apply_overrides(overrides) if overrides && !overrides.empty?
    end

    # Apply CLI or runtime overrides to configuration
    #
    # @param overrides [Hash] key-value pairs to override
    def apply_overrides(overrides)
      overrides.each do |key, value|
        next if value.nil?

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
        context_files: context_files
      }
    end

    private

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

      if output.log_file
        output.log_file = File.expand_path(output.log_file)
      end
    end

    def ensure_arrays
      # Ensure array fields are actually arrays
      self.pipeline = [] if pipeline.nil?
      self.require_libs = [] if require_libs.nil?
      self.context_files = [] if context_files.nil?
      self.mcp_servers = [] if mcp_servers.nil?

      # Ensure tools.paths is an array
      tools.paths = [] if tools.paths.nil?
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
