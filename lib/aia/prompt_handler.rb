# lib/aia/prompt_handler.rb

require 'pm'
require 'erb'

module AIA
  # :reek:TooManyMethods -- prompt/role fetching, front-matter merging, and fzf search form one lookup pipeline of small named steps
  class PromptHandler
    include AIA::SkillUtils

    # Struct for path-based role content (bypasses PM parsing)
    RoleContent = Struct.new(:content) do
      def to_s = content
      def metadata = nil
    end

    # Root-level YAML keys that are shorthands for deeper config paths
    SHORTHAND_KEYS = %w[model temperature top_p next pipeline shell erb].freeze

    # Maps root shorthand keys to their config paths for conflict detection
    SHORTHAND_CONFLICTS = {
      'model'       => [%w[config model], %w[config models]],
      'temperature' => [%w[config temperature], %w[config llm temperature]],
      'top_p'       => [%w[config top_p], %w[config llm top_p]],
      'next'        => [%w[config next], %w[config pipeline]],
      'pipeline'    => [%w[config pipeline], %w[config next]],
      'shell'       => [%w[config shell], %w[config flags shell]],
      'erb'         => [%w[config erb], %w[config flags erb]]
    }.freeze

    def initialize
      @prompts_dir = AIA.config.prompts.dir
      @roles_dir   = AIA.config.prompts.roles_dir

      PM.configure do |c|
        c.prompts_dir = @prompts_dir
      end

      register_pm_directives
    end

    def fetch_prompt(prompt_id)
      if prompt_id == '__FUZZY_SEARCH__'
        return fuzzy_search_prompt('')
      end

      if prompt_id == '__EXECUTABLE_PROMPT__'
        return fetch_executable_prompt
      end

      prompt_file_path = File.join(@prompts_dir, "#{prompt_id}#{AIA.config.prompts.extname}")

      parsed = if File.exist?(prompt_file_path)
                 PM.parse(prompt_id)
               else
                 $stderr.puts "Warning: Invalid prompt ID or file not found: #{prompt_id}"
                 logger.warn("Invalid prompt ID or file not found: #{prompt_id}")
                 handle_missing_prompt(prompt_id)
               end

      apply_metadata_config(parsed) if parsed
      parsed
    end

    def fetch_role(role_id)
      return handle_missing_role("roles/") if role_id.nil?
      return fetch_role_from_path(role_id) if path_based_id?(role_id)

      prompts_cfg = AIA.config.prompts
      unless role_id.start_with?(prompts_cfg.roles_prefix)
        role_id = "#{prompts_cfg.roles_prefix}/#{role_id}"
      end

      role_file_path = File.join(@prompts_dir, "#{role_id}#{prompts_cfg.extname}")

      parsed = if File.exist?(role_file_path)
                 # PM.parse(role_id) cannot resolve subdirectory IDs like "roles/jersey_mike"
                 # and returns the ID string as content.  Parse from raw file content instead.
                 PM.parse_string(File.read(role_file_path))
               else
                 $stderr.puts "Warning: Invalid role ID or file not found: #{role_id}"
                 logger.warn("Invalid role ID or file not found: #{role_id}")
                 handle_missing_role(role_id)
               end

      apply_metadata_config(parsed) if parsed
      parsed
    end

    # Load role for a specific model (ADR-005)
    # Takes a model spec hash and default role, returns rendered role text
    def load_role_for_model(model_spec, default_role = nil)
      role_id = if model_spec.is_a?(Hash)
                  model_spec[:role] || default_role
                else
                  default_role
                end

      return nil if role_id.nil? || role_id.empty?

      role_parsed = fetch_role(role_id)
      role_parsed.to_s
    rescue => e
      $stderr.puts "Warning: Could not load role '#{role_id}' for model: #{e.message}"
      logger.warn("Could not load role '#{role_id}' for model: #{e.message}")
      nil
    end

    # Applies YAML front matter metadata to AIA.config.
    # Processes root-level shorthand keys, detects conflicts with config: section,
    # and deep merges the config: section into AIA.config.
    def apply_metadata_config(parsed)
      return unless parsed&.metadata

      meta = parsed.metadata
      meta_hash = meta.to_h

      # Extract the config section and root-level shorthands
      config_section = meta_hash['config'] || meta_hash[:config]
      config_section = symbolize_keys_deep(config_section) if config_section

      # Detect conflicts between root shorthands and config: section
      detect_shorthand_conflicts(meta_hash, config_section)

      # Apply root-level shorthands
      apply_root_shorthands(meta_hash)

      # Deep merge config: section into AIA.config
      deep_merge_config(config_section) if config_section
    end

    private

    def fetch_executable_prompt
      content = AIA.config.executable_prompt_content
      parsed = PM.parse(content)
      apply_metadata_config(parsed) if parsed
      parsed
    end

    def register_pm_directives
      AIA::Directive.register_all
    end

    # Detect conflicts between root shorthand keys and the config: section.
    # Raises AIA::ConfigurationError when the same setting is specified in both places.
    def detect_shorthand_conflicts(meta_hash, config_section)
      # Check for mutually exclusive root keys: next and pipeline
      has_next     = meta_hash.key?('next') || meta_hash.key?(:next)
      has_pipeline = meta_hash.key?('pipeline') || meta_hash.key?(:pipeline)

      if has_next && has_pipeline
        raise ConfigurationError, "Both 'next' and 'pipeline' specified at root level — they are mutually exclusive"
      end

      return unless config_section

      SHORTHAND_CONFLICTS.each do |root_key, conflict_paths|
        root_present = meta_hash.key?(root_key) || meta_hash.key?(root_key.to_sym)
        next unless root_present

        conflict_paths.each do |path|
          # path is like ['config', 'llm', 'temperature'] — skip the 'config' prefix
          nested_keys = path[1..]
          value = dig_hash(config_section, nested_keys.map(&:to_sym))

          unless value.nil?
            raise ConfigurationError,
                  "Conflict: '#{root_key}' at root level and '#{path.join('.')}' in config section"
          end
        end
      end
    end

    # Apply root-level shorthand keys to AIA.config
    # :reek:TooManyStatements -- one guarded assignment per supported front-matter shorthand key
    def apply_root_shorthands(meta_hash)
      cfg = AIA.config

      # model → cfg.models (replace with single-model array)
      model_val = shorthand(meta_hash, :model)
      cfg.models = [model_val] if model_val

      temp_val = shorthand(meta_hash, :temperature)
      cfg.llm.temperature = temp_val if temp_val

      top_p_val = shorthand(meta_hash, :top_p)
      cfg.llm.top_p = top_p_val if top_p_val

      # next / pipeline → cfg.pipeline (replace)
      next_val = shorthand(meta_hash, :next)
      apply_pipeline_shorthand(cfg, [next_val], "next: #{next_val}") if next_val

      pipeline_val = shorthand(meta_hash, :pipeline)
      apply_pipeline_shorthand(cfg, Array(pipeline_val), "pipeline") if pipeline_val

      # shell / erb → cfg.flags (and PM's shell/erb via metadata)
      shell_val = shorthand(meta_hash, :shell)
      cfg.flags.shell = shell_val unless shell_val.nil?

      erb_val = shorthand(meta_hash, :erb)
      cfg.flags.erb = erb_val unless erb_val.nil?
    end

    # Fetch a front-matter shorthand value by string or symbol key.
    def shorthand(meta_hash, key)
      meta_hash[key.to_s] || meta_hash[key]
    end

    # Replace cfg.pipeline, logging when a remaining pipeline is overridden.
    def apply_pipeline_shorthand(cfg, new_pipeline, label)
      if cfg.pipeline.any?
        logger.info "Prompt metadata '#{label}' overrides remaining pipeline #{cfg.pipeline.inspect}"
      end
      cfg.pipeline = new_pipeline
    end

    def logger
      @logger ||= LoggerManager.aia_logger
    end

    # Deep merge config: section into AIA.config
    def deep_merge_config(config_section)
      config_section.each do |key, value|
        target = AIA.config

        if value.is_a?(Hash)
          # Navigate to the nested config object
          sub_config = target.respond_to?(key) ? target.send(key) : nil
          if sub_config
            deep_merge_into_config(sub_config, value)
          end
        elsif target.respond_to?(:"#{key}=")
          target.send(:"#{key}=", value)
        end
      end
    end

    # Recursively merge a hash into a config object
    def deep_merge_into_config(config_obj, hash)
      hash.each do |key, value|
        if value.is_a?(Hash) && config_obj.respond_to?(key)
          sub = config_obj.send(key)
          deep_merge_into_config(sub, value) if sub
        elsif config_obj.respond_to?(:"#{key}=")
          config_obj.send(:"#{key}=", value)
        end
      end
    end

    # Dig into a hash with an array of keys, returning nil if any key is missing
    def dig_hash(hash, keys)
      keys.reduce(hash) do |h, key|
        return nil unless h.is_a?(Hash)
        h[key] || h[key.to_s]
      end
    end

    # Recursively symbolize all keys in a hash
    def symbolize_keys_deep(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), memo|
          memo[k.to_sym] = symbolize_keys_deep(v)
        end
      when Array
        obj.map { |v| symbolize_keys_deep(v) }
      else
        obj
      end
    end

    def handle_missing_prompt(prompt_id)
      prompt_id = prompt_id.to_s.strip
      if prompt_id.empty?
        $stderr.puts "Error: Prompt ID cannot be empty"
        exit 1
      end

      if AIA.config.flags.fuzzy
        fuzzy_search_prompt(prompt_id)
      else
        $stderr.puts "Error: Could not find prompt with ID: #{prompt_id}"
        exit 1
      end
    end

    def fetch_role_from_path(role_id)
      expanded = File.expand_path(role_id)
      expanded += '.md' if File.extname(expanded).empty?

      unless File.exist?(expanded)
        $stderr.puts "Warning: Role file not found at path: #{expanded}"
        logger.warn("Role file not found at path: #{expanded}")
        return handle_missing_role(role_id)
      end

      RoleContent.new(File.read(expanded))
    end

    def fuzzy_search_prompt(prompt_id)
      new_prompt_id = search_prompt_id_with_fzf(prompt_id)

      if new_prompt_id.nil? || new_prompt_id.empty?
        raise "Error: Could not find prompt with ID: #{prompt_id} even with fuzzy search"
      end

      PM.parse(new_prompt_id)
    end

    def handle_missing_role(role_id)
      role_id = role_id.to_s.strip
      if role_id.empty? || role_id == "roles/"
        $stderr.puts "Error: Role ID cannot be empty"
        exit 1
      end

      if AIA.config.flags.fuzzy
        fuzzy_search_role(role_id)
      else
        $stderr.puts "Error: Could not find role with ID: #{role_id}"
        exit 1
      end
    end

    def fuzzy_search_role(role_id)
      new_role_id = search_role_id_with_fzf(role_id)
      if new_role_id.nil? || new_role_id.empty?
        raise "Error: Could not find role with ID: #{role_id} even with fuzzy search"
      end

      PM.parse(new_role_id)
    end

    def search_prompt_id_with_fzf(initial_query)
      prompt_files = Dir.glob(File.join(@prompts_dir, "*#{AIA.config.prompts.extname}"))
                        .map { |file| File.basename(file, AIA.config.prompts.extname) }
      fzf = AIA::Fzf.new(
        list: prompt_files,
        directory: @prompts_dir,
        query: initial_query,
        subject: 'Prompt IDs',
        prompt: 'Select a prompt ID:'
      )
      fzf.run || (raise "No prompt ID selected")
    end

    def search_role_id_with_fzf(initial_query)
      prompts_cfg = AIA.config.prompts
      role_files = Dir.glob(File.join(@roles_dir, "*#{prompts_cfg.extname}"))
                      .map { |file| File.basename(file, prompts_cfg.extname) }
      fzf = AIA::Fzf.new(
        list: role_files,
        directory: @prompts_dir,
        query: initial_query,
        subject: 'Role IDs',
        prompt: 'Select a role ID:'
      )

      role = fzf.run

      if role.nil? || role.empty?
        raise "No role ID selected"
      end

      unless role.start_with?(prompts_cfg.roles_prefix)
        role = prompts_cfg.roles_prefix + '/' + role
      end

      role
    end
  end
end
