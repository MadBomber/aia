# lib/aia/prompt_handler.rb

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'
require 'erb'


module AIA
  class PromptHandler
    def initialize
      @prompts_dir         = AIA.config.prompts.dir
      @roles_dir           = AIA.config.prompts.roles_dir # A sub-directory of @prompts_dir
      @directive_processor = AIA::DirectiveProcessor.new

      PromptManager::Prompt.storage_adapter =
        PromptManager::Storage::FileSystemAdapter.config do |c|
          c.prompts_dir      = @prompts_dir
          c.prompt_extension = AIA.config.prompts.extname
          c.params_extension = '.json' # default
        end.new
    end


    def get_prompt(prompt_id, role_id = '')
      prompt = fetch_prompt(prompt_id)

      unless role_id.empty?
        role_prompt = fetch_role(role_id)
        prompt.text.prepend(role_prompt.text)
      end

      prompt
    end

    def fetch_prompt(prompt_id)
      # Special case for fuzzy search without an initial query
      if prompt_id == '__FUZZY_SEARCH__'
        return fuzzy_search_prompt('')
      end

      # First check if the prompt file exists to avoid ArgumentError from PromptManager
      prompt_file_path = File.join(@prompts_dir, "#{prompt_id}.txt")
      if File.exist?(prompt_file_path)
        prompt = PromptManager::Prompt.new(
          id: prompt_id,
          directives_processor: @directive_processor,
          external_binding: binding,
          erb_flag: AIA.config.flags.erb,
          envar_flag: AIA.config.flags.shell
        )

        # Parameters should be extracted during initialization or to_s
        return prompt if prompt
      else
        puts "Warning: Invalid prompt ID or file not found: #{prompt_id}"
      end

      handle_missing_prompt(prompt_id)
    end

    def handle_missing_prompt(prompt_id)
      # Handle empty/nil prompt_id
      prompt_id = prompt_id.to_s.strip
      if prompt_id.empty?
        STDERR.puts "Error: Prompt ID cannot be empty"
        exit 1
      end
      
      if AIA.config.flags.fuzzy
        return fuzzy_search_prompt(prompt_id)
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

      prompt = PromptManager::Prompt.new(
        id: new_prompt_id,
        directives_processor: @directive_processor,
        external_binding: binding,
        erb_flag: AIA.config.flags.erb,
        envar_flag: AIA.config.flags.shell
      )

      raise "Error: Could not find prompt with ID: #{prompt_id} even with fuzzy search" if prompt.nil?

      prompt
    end

    def fetch_role(role_id)
      # Handle nil role_id
      return handle_missing_role("roles/") if role_id.nil?

      # Prepend roles_prefix if not already present
      unless role_id.start_with?(AIA.config.prompts.roles_prefix)
        role_id = "#{AIA.config.prompts.roles_prefix}/#{role_id}"
      end

      # NOTE: roles_prefix is a sub-directory of the prompts directory
      role_file_path = File.join(@prompts_dir, "#{role_id}.txt")

      if File.exist?(role_file_path)
        role_prompt = PromptManager::Prompt.new(
          id: role_id,
          directives_processor: @directive_processor,
          external_binding: binding,
          erb_flag: AIA.config.flags.erb,
          envar_flag: AIA.config.flags.shell
        )
        return role_prompt if role_prompt
      else
        puts "Warning: Invalid role ID or file not found: #{role_id}"
      end

      handle_missing_role(role_id)
    end

    # Load role for a specific model (ADR-005)
    # Takes a model spec hash and default role, returns role text
    def load_role_for_model(model_spec, default_role = nil)
      # Determine which role to use
      role_id = if model_spec.is_a?(Hash)
                  model_spec[:role] || default_role
                else
                  # Backward compatibility: if model_spec is a string, use default role
                  default_role
                end

      return nil if role_id.nil? || role_id.empty?

      # Load the role using existing fetch_role method
      role_prompt = fetch_role(role_id)
      role_prompt.text
    rescue => e
      puts "Warning: Could not load role '#{role_id}' for model: #{e.message}"
      nil
    end

    def handle_missing_role(role_id)
      # Handle empty/nil role_id
      role_id = role_id.to_s.strip
      if role_id.empty? || role_id == "roles/"
        STDERR.puts "Error: Role ID cannot be empty"
        exit 1
      end
      
      if AIA.config.flags.fuzzy
        return fuzzy_search_role(role_id)
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

      role_prompt = PromptManager::Prompt.new(
        id: new_role_id,
        directives_processor: @directive_processor,
        external_binding: binding,
        erb_flag: AIA.config.flags.erb,
        envar_flag: AIA.config.flags.shell
      )

      raise "Error: Could not find role with ID: #{role_id} even with fuzzy search" if role_prompt.nil?
      role_prompt
    end


    # FIXME: original implementation used a search_proc to look into the content of the prompt
    #        files.  The use of the select statement does not work.
    def search_prompt_id_with_fzf(initial_query)
      prompt_files = Dir.glob(File.join(@prompts_dir, "*.txt"))
                       .map { |file| File.basename(file, ".txt") }
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
      role_files = Dir.glob(File.join(@roles_dir, "*.txt"))
                    .map { |file| File.basename(file, ".txt") }
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
