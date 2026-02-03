# lib/aia/prompt_handler.rb

require 'pm'
require 'erb'


module AIA
  class PromptHandler
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
      'erb'         => [%w[config erb], %w[config flags erb]],
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

      prompt_file_path = File.join(@prompts_dir, "#{prompt_id}#{AIA.config.prompts.extname}")

      parsed = if File.exist?(prompt_file_path)
                 PM.parse(prompt_id)
               else
                 puts "Warning: Invalid prompt ID or file not found: #{prompt_id}"
                 handle_missing_prompt(prompt_id)
               end

      apply_metadata_config(parsed) if parsed
      parsed
    end


    def fetch_role(role_id)
      return handle_missing_role("roles/") if role_id.nil?

      unless role_id.start_with?(AIA.config.prompts.roles_prefix)
        role_id = "#{AIA.config.prompts.roles_prefix}/#{role_id}"
      end

      role_file_path = File.join(@prompts_dir, "#{role_id}#{AIA.config.prompts.extname}")

      parsed = if File.exist?(role_file_path)
                 PM.parse(role_id)
               else
                 puts "Warning: Invalid role ID or file not found: #{role_id}"
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
      puts "Warning: Could not load role '#{role_id}' for model: #{e.message}"
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


    # Register all AIA directives with PM so they're available in ERB templates
    # and as a single source of truth for directive lookup.
    # Block signature: (ctx, *args) where ctx is PM::RenderContext (ERB) or nil (chat mode).
    # Return convention: non-blank string = content for LLM, nil = operational side-effect only.
    def register_pm_directives
      # Content directives — return string content for LLM

      PM.register(:webpage, :website, :web) do |_ctx, *args|
        Directives::WebAndFile.webpage(Array(args).flatten, nil)
      end

      PM.register(:paste, :clipboard) do |_ctx, *args|
        Directives::WebAndFile.paste(Array(args).flatten, nil)
      end

      # Operational directives — perform side effects, return nil

      PM.register(:config, :cfg) do |_ctx, *args|
        Directives::Configuration.config(Array(args).flatten, nil)
        nil
      end

      PM.register(:model) do |_ctx, *args|
        Directives::Configuration.model(Array(args).flatten, nil)
        nil
      end

      PM.register(:temperature, :temp) do |_ctx, *args|
        Directives::Configuration.temperature(Array(args).flatten, nil)
        nil
      end

      PM.register(:top_p, :topp) do |_ctx, *args|
        Directives::Configuration.top_p(Array(args).flatten, nil)
        nil
      end

      PM.register(:tools) do |_ctx, *args|
        Directives::Utility.tools(Array(args).flatten, nil)
        nil
      end

      PM.register(:next) do |_ctx, *args|
        Directives::Utility.next(Array(args).flatten, nil)
        nil
      end

      PM.register(:pipeline, :workflow) do |_ctx, *args|
        Directives::Utility.pipeline(Array(args).flatten, nil)
        nil
      end

      PM.register(:terse) do |_ctx, *args|
        Directives::Utility.terse(Array(args).flatten, nil)
      end

      PM.register(:robot) do |_ctx, *args|
        Directives::Utility.robot(Array(args).flatten, nil)
        nil
      end

      PM.register(:ruby, :rb) do |_ctx, *args|
        Directives::Execution.ruby(Array(args).flatten, nil)
      end

      PM.register(:shell, :sh) do |_ctx, *args|
        Directives::Execution.shell(Array(args).flatten, nil)
      end

      PM.register(:say) do |_ctx, *args|
        Directives::Execution.say(Array(args).flatten, nil)
        nil
      end

      PM.register(:help) do |_ctx, *args|
        Directives::Models.help(Array(args).flatten, nil)
        nil
      end

      PM.register(:available_models, :models, :all_models, :am, :llms, :available) do |_ctx, *args|
        Directives::Models.available_models(Array(args).flatten, nil)
        nil
      end

      PM.register(:compare, :cmp) do |_ctx, *args|
        Directives::Models.compare(Array(args).flatten, nil)
        nil
      end

      PM.register(:clear) do |_ctx, *args|
        Directives::Checkpoint.clear(Array(args).flatten, nil)
        nil
      end

      PM.register(:checkpoint, :ckp, :cp) do |_ctx, *args|
        Directives::Checkpoint.checkpoint(Array(args).flatten, nil)
        nil
      end

      PM.register(:restore) do |_ctx, *args|
        Directives::Checkpoint.restore(Array(args).flatten, nil)
        nil
      end

      PM.register(:review, :context) do |_ctx, *args|
        Directives::Checkpoint.review(Array(args).flatten, nil)
        nil
      end

      PM.register(:checkpoints_list, :checkpoints) do |_ctx, *args|
        Directives::Checkpoint.checkpoints_list(Array(args).flatten, nil)
        nil
      end
    rescue RuntimeError => e
      # Directives already registered (e.g., multiple PromptHandler instances)
      # PM.register raises if a name is already taken — safe to ignore on re-init
      nil unless e.message.start_with?('Directive already registered')
      raise unless e.message.start_with?('Directive already registered')
    end


    # Detect conflicts between root shorthand keys and the config: section.
    # Raises AIA::ConfigurationError when the same setting is specified in both places.
    def detect_shorthand_conflicts(meta_hash, config_section)
      # Check for mutually exclusive root keys: next and pipeline
      has_next     = meta_hash.key?('next')     || meta_hash.key?(:next)
      has_pipeline = meta_hash.key?('pipeline')  || meta_hash.key?(:pipeline)

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
    def apply_root_shorthands(meta_hash)
      # model → AIA.config.models (replace with single-model array)
      model_val = meta_hash['model'] || meta_hash[:model]
      if model_val
        AIA.config.models = [model_val]
      end

      # temperature → AIA.config.llm.temperature
      temp_val = meta_hash['temperature'] || meta_hash[:temperature]
      if temp_val
        AIA.config.llm.temperature = temp_val
      end

      # top_p → AIA.config.llm.top_p
      top_p_val = meta_hash['top_p'] || meta_hash[:top_p]
      if top_p_val
        AIA.config.llm.top_p = top_p_val
      end

      # next → AIA.config.pipeline (replace)
      next_val = meta_hash['next'] || meta_hash[:next]
      if next_val
        AIA.config.pipeline = [next_val]
      end

      # pipeline → AIA.config.pipeline (replace)
      pipeline_val = meta_hash['pipeline'] || meta_hash[:pipeline]
      if pipeline_val
        AIA.config.pipeline = Array(pipeline_val)
      end

      # shell → AIA.config.flags.shell (and PM's shell via metadata)
      shell_val = meta_hash['shell'] || meta_hash[:shell]
      unless shell_val.nil?
        AIA.config.flags.shell = shell_val
      end

      # erb → AIA.config.flags.erb (and PM's erb via metadata)
      erb_val = meta_hash['erb'] || meta_hash[:erb]
      unless erb_val.nil?
        AIA.config.flags.erb = erb_val
      end
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
        STDERR.puts "Error: Prompt ID cannot be empty"
        exit 1
      end

      if AIA.config.flags.fuzzy
        fuzzy_search_prompt(prompt_id)
      else
        STDERR.puts "Error: Could not find prompt with ID: #{prompt_id}"
        exit 1
      end
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
        STDERR.puts "Error: Role ID cannot be empty"
        exit 1
      end

      if AIA.config.flags.fuzzy
        fuzzy_search_role(role_id)
      else
        STDERR.puts "Error: Could not find role with ID: #{role_id}"
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
      role_files = Dir.glob(File.join(@roles_dir, "*#{AIA.config.prompts.extname}"))
                    .map { |file| File.basename(file, AIA.config.prompts.extname) }
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

      unless role.start_with?(AIA.config.prompts.roles_prefix)
        role = AIA.config.prompts.roles_prefix + '/' + role
      end

      role
    end
  end
end
