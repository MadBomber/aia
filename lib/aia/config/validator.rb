# lib/aia/config/validator.rb

require 'ostruct'

module AIA
  module ConfigModules
    module Validator
      class << self
        def tailor_the_config(config)
          remaining_args = config.remaining_args.dup
          config.remaining_args = nil

          stdin_content = process_stdin_content
          config.stdin_content = stdin_content if stdin_content && !stdin_content.strip.empty?

          process_prompt_id_from_args(config, remaining_args)
          validate_and_set_context_files(config, remaining_args)
          handle_executable_prompt(config)
          validate_required_prompt_id(config)
          process_role_configuration(config)
          handle_fuzzy_search_prompt_id(config)
          normalize_boolean_flags(config)
          handle_completion_script(config)
          validate_final_prompt_requirements(config)
          configure_prompt_manager(config)
          prepare_pipeline(config)
          validate_pipeline_prompts(config)

          config
        end

        def process_stdin_content
          stdin_content = ''

          if !STDIN.tty? && !STDIN.closed?
            begin
              stdin_content << "\n" + STDIN.read
              STDIN.reopen('/dev/tty')  # Reopen STDIN for interactive use
            rescue => _
              # If we can't reopen, continue without error
            end
          end

          stdin_content
        end

        def process_prompt_id_from_args(config, remaining_args)
          return if remaining_args.empty?

          maybe_id = remaining_args.first
          maybe_id_plus = File.join(config.prompts_dir, maybe_id + config.prompt_extname)

          if AIA.bad_file?(maybe_id) && AIA.good_file?(maybe_id_plus)
            config.prompt_id = remaining_args.shift
          end
        end

        def validate_and_set_context_files(config, remaining_args)
          return if remaining_args.empty?

          bad_files = remaining_args.reject { |filename| AIA.good_file?(filename) }
          if bad_files.any?
            STDERR.puts "Error: The following files do not exist: #{bad_files.join(', ')}"
            exit 1
          end

          config.context_files ||= []
          config.context_files += remaining_args
        end

        def handle_executable_prompt(config)
          return unless config.executable_prompt && config.context_files && !config.context_files.empty?

          config.executable_prompt_file = config.context_files.pop
        end

        def validate_required_prompt_id(config)
          return unless config.prompt_id.nil? && !config.chat && !config.fuzzy

          STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
          exit 1
        end

        def process_role_configuration(config)
          return if config.role.empty?

          unless config.roles_prefix.empty?
            unless config.role.start_with?(config.roles_prefix)
              config.role.prepend "#{config.roles_prefix}/"
            end
          end

          config.roles_dir ||= File.join(config.prompts_dir, config.roles_prefix)

          if config.prompt_id.nil? || config.prompt_id.empty?
            if !config.role.nil? && !config.role.empty?
              config.prompt_id = config.role
              config.pipeline.prepend config.prompt_id
              config.role = ''
            end
          end
        end

        def handle_fuzzy_search_prompt_id(config)
          return unless config.fuzzy && config.prompt_id.empty?

          # When fuzzy search is enabled but no prompt ID is provided,
          # set a special value to trigger fuzzy search without an initial query
          # SMELL: This feels like a cludge
          config.prompt_id = '__FUZZY_SEARCH__'
        end

        def normalize_boolean_flags(config)
          normalize_boolean_flag(config, :chat)
          normalize_boolean_flag(config, :fuzzy)
        end

        def normalize_boolean_flag(config, flag)
          return if [TrueClass, FalseClass].include?(config[flag].class)

          config[flag] = if config[flag].nil? || config[flag].empty?
                           false
                         else
                           true
                         end
        end

        def handle_completion_script(config)
          return unless config.completion

          FileLoader.generate_completion_script(config.completion)
          exit
        end

        def validate_final_prompt_requirements(config)
          # Only require a prompt_id if we're not in chat mode, not using fuzzy search, and no context files
          if !config.chat && !config.fuzzy && (config.prompt_id.nil? || config.prompt_id.empty?) && (!config.context_files || config.context_files.empty?)
            STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
            exit 1
          end

          # If we're in chat mode with context files but no prompt_id, that's valid
          # This is handled implicitly - no action needed
        end

        def configure_prompt_manager(config)
          return unless config.parameter_regex

          PromptManager::Prompt.parameter_regex = Regexp.new(config.parameter_regex)
        end

        def prepare_pipeline(config)
          return if config.prompt_id.nil? || config.prompt_id.empty? || config.prompt_id == config.pipeline.first

          config.pipeline.prepend config.prompt_id
        end

        def validate_pipeline_prompts(config)
          return if config.pipeline.empty?

          and_exit = false

          config.pipeline.each do |prompt_id|
            # Skip empty prompt IDs (can happen in chat-only mode)
            next if prompt_id.nil? || prompt_id.empty?

            prompt_file_path = File.join(config.prompts_dir, "#{prompt_id}.txt")
            unless File.exist?(prompt_file_path)
              STDERR.puts "Error: Prompt ID '#{prompt_id}' does not exist at #{prompt_file_path}"
              and_exit = true
            end
          end

          exit(1) if and_exit
        end
      end
    end
  end
end
