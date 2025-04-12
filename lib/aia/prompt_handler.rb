# lib/aia/prompt_handler.rb

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'
require 'erb'


module AIA
  class PromptHandler
    def initialize
      @prompts_dir         = AIA.config.prompts_dir
      @roles_dir           = AIA.config.roles_dir
      @directive_processor = AIA::DirectiveProcessor.new

      PromptManager::Prompt.storage_adapter =
        PromptManager::Storage::FileSystemAdapter.config do |c|
          c.prompts_dir      = @prompts_dir
          c.prompt_extension = '.txt'  # default
          c.params_extension = '.json' # default
        end.new
    end


    def get_prompt(prompt_id, role_id = nil)
      prompt = fetch_prompt(prompt_id)

      if role_id
        role_prompt = fetch_role(role_id)
        prompt.text = combine_prompt_with_role(prompt.text, role_prompt.text)
      end

      prompt
    end

    def fetch_prompt(prompt_id)
      # First check if the prompt file exists to avoid ArgumentError from PromptManager
      prompt_file_path = File.join(@prompts_dir, "#{prompt_id}.txt")
      if File.exist?(prompt_file_path)
        prompt = PromptManager::Prompt.new(
          id: prompt_id,
          directives_processor: @directive_processor,
          external_binding: binding,
          erb_flag: AIA.config.erb,
          envar_flag: AIA.config.shell
        )

        return prompt if prompt
      else
        puts "Warning: Invalid prompt ID or file not found: #{prompt_id}"
      end

      handle_missing_prompt(prompt_id)
    end

    def handle_missing_prompt(prompt_id)
      if AIA.config.fuzzy
        return fuzzy_search_prompt(prompt_id)
      elsif AIA.config.fuzzy
        puts "Warning: Fuzzy search is enabled but Fzf tool is not available."
        raise "Error: Could not find prompt with ID: #{prompt_id}"
      else
        raise "Error: Could not find prompt with ID: #{prompt_id}"
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
        erb_flag: AIA.config.erb,
        envar_flag: AIA.config.shell
      )

      raise "Error: Could not find prompt with ID: #{prompt_id} even with fuzzy search" if prompt.nil?

      prompt
    end

    def fetch_role(role_id)
      # First check if the role file exists to avoid ArgumentError from PromptManager
      role_file_path = File.join(@prompts_dir, "#{role_id}.txt")
      if File.exist?(role_file_path)
        role_prompt = PromptManager::Prompt.new(
          id: role_id,
          directives_processor: @directive_processor,
          external_binding: binding,
          erb_flag: AIA.config.erb,
          envar_flag: AIA.config.shell
        )
        return role_prompt if role_prompt
      else
        puts "Warning: Invalid role ID or file not found: #{role_id}"
      end

      handle_missing_role(role_id)
    end

    def handle_missing_role(role_id)
      if AIA.config.fuzzy && defined?(AIA::Fzf)
        return fuzzy_search_role(role_id)
      elsif AIA.config.fuzzy
        puts "Warning: Fuzzy search is enabled but Fzf tool is not available."
        raise "Error: Could not find role with ID: #{role_id}"
      else
        raise "Error: Could not find role with ID: #{role_id}"
      end
    end

    def fuzzy_search_role(role_id)
      new_role_id = search_prompt_id_with_fzf(role_id)
      if new_role_id.nil? || new_role_id.empty?
        raise "Error: Could not find role with ID: #{role_id} even with fuzzy search"
      end

      role_prompt = PromptManager::Prompt.new(
        id: new_role_id,
        directives_processor: @directive_processor,
        external_binding: binding,
        erb_flag: AIA.config.erb,
        envar_flag: AIA.config.shell
      )

      raise "Error: Could not find role with ID: #{role_id} even with fuzzy search" if role_prompt.nil?
      role_prompt
    end

    def combine_prompt_with_role(prompt_text, role_text)
      <<~TEXT
        #{role_text}
        #{prompt_text}
      TEXT
    end

    def search_prompt_id_with_fzf(initial_query)
      prompt_files = Dir.glob(File.join(@prompts_dir, "*.txt")).map { |file| File.basename(file, ".txt") }
      fzf = AIA::Fzf.new(
        list: prompt_files,
        directory: @prompts_dir,
        query: initial_query,
        subject: 'Prompt IDs',
        prompt: 'Select a prompt ID:'
      )
      fzf.run || (raise "No prompt ID selected")
    end
  end
end
