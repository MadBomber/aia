# lib/aia/prompt_handler.rb

require 'pm'
require 'erb'


module AIA
  class PromptHandler
    def initialize
      @prompts_dir = AIA.config.prompts.dir
      @roles_dir   = AIA.config.prompts.roles_dir

      PM.configure do |c|
        c.prompts_dir = @prompts_dir
      end
    end


    def fetch_prompt(prompt_id)
      if prompt_id == '__FUZZY_SEARCH__'
        return fuzzy_search_prompt('')
      end

      prompt_file_path = File.join(@prompts_dir, "#{prompt_id}#{AIA.config.prompts.extname}")

      if File.exist?(prompt_file_path)
        PM.parse(prompt_id)
      else
        puts "Warning: Invalid prompt ID or file not found: #{prompt_id}"
        handle_missing_prompt(prompt_id)
      end
    end


    def fetch_role(role_id)
      return handle_missing_role("roles/") if role_id.nil?

      unless role_id.start_with?(AIA.config.prompts.roles_prefix)
        role_id = "#{AIA.config.prompts.roles_prefix}/#{role_id}"
      end

      role_file_path = File.join(@prompts_dir, "#{role_id}#{AIA.config.prompts.extname}")

      if File.exist?(role_file_path)
        PM.parse(role_id)
      else
        puts "Warning: Invalid role ID or file not found: #{role_id}"
        handle_missing_role(role_id)
      end
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
