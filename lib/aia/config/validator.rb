# frozen_string_literal: true

# lib/aia/config/validator.rb
#
# Validates and tailors configuration after it's been loaded.
# Handles prompt ID extraction, context file validation, role processing, etc.

module AIA
  module ConfigValidator
    class << self
      # Tailor and validate the configuration
      #
      # @param config [AIA::Config] the configuration to validate
      # @return [AIA::Config] the validated configuration
      def tailor(config)
        remaining_args = config.remaining_args&.dup || []
        config.remaining_args = nil

        # Process STDIN content if available
        stdin_content = process_stdin_content
        config.stdin_content = stdin_content if stdin_content && !stdin_content.strip.empty?

        # Process arguments and validate
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
            STDIN.reopen('/dev/tty')
          rescue => _
            # If we can't reopen, continue without error
          end
        end

        stdin_content
      end

      def process_prompt_id_from_args(config, remaining_args)
        return if remaining_args.empty?

        maybe_id = remaining_args.first
        maybe_id_plus = File.join(config.prompts.dir, maybe_id + config.prompts.extname)

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
        return unless config.prompt_id.nil? && !(config.flags.chat == true) && !(config.flags.fuzzy == true)

        STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
        exit 1
      end

      def process_role_configuration(config)
        role = config.prompts.role
        return if role.nil? || role.empty?

        roles_prefix = config.prompts.roles_prefix
        unless roles_prefix.nil? || roles_prefix.empty?
          unless role.start_with?(roles_prefix)
            config.prompts.role = "#{roles_prefix}/#{role}"
            role = config.prompts.role
          end
        end

        config.prompts.roles_dir ||= File.join(config.prompts.dir, roles_prefix)

        if config.prompt_id.nil? || config.prompt_id.empty?
          unless role.nil? || role.empty?
            config.prompt_id = role
            config.pipeline.prepend(config.prompt_id)
            config.prompts.role = ''
          end
        end
      end

      def handle_fuzzy_search_prompt_id(config)
        return unless (config.flags.fuzzy == true) && (config.prompt_id.nil? || config.prompt_id.empty?)

        config.prompt_id = '__FUZZY_SEARCH__'
      end

      def normalize_boolean_flags(config)
        normalize_boolean_flag(config.flags, :chat)
        normalize_boolean_flag(config.flags, :fuzzy)
        normalize_boolean_flag(config.flags, :consensus)
      end

      def normalize_boolean_flag(flags_section, flag)
        value = flags_section.send(flag)
        return if [TrueClass, FalseClass].include?(value.class)

        normalized = case value
                     when nil, '', 'false', false
                       false
                     when 'true', true
                       true
                     else
                       true
                     end

        flags_section.send("#{flag}=", normalized)
      end

      def handle_completion_script(config)
        return unless config.completion

        generate_completion_script(config.completion)
        exit
      end

      def generate_completion_script(shell)
        script_path = File.join(File.dirname(__FILE__), "../../aia_completion.#{shell}")

        if File.exist?(script_path)
          puts File.read(script_path)
        else
          STDERR.puts "ERROR: The shell '#{shell}' is not supported or the completion script is missing."
        end
      end

      def validate_final_prompt_requirements(config)
        chat_mode = config.flags.chat == true
        fuzzy_mode = config.flags.fuzzy == true
        if !chat_mode && !fuzzy_mode && (config.prompt_id.nil? || config.prompt_id.empty?) && (config.context_files.nil? || config.context_files.empty?)
          STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
          exit 1
        end
      end

      def configure_prompt_manager(config)
        return unless config.prompts.parameter_regex

        PromptManager::Prompt.parameter_regex = Regexp.new(config.prompts.parameter_regex)
      end

      def prepare_pipeline(config)
        return if config.prompt_id.nil? || config.prompt_id.empty? || config.prompt_id == config.pipeline.first

        config.pipeline.prepend(config.prompt_id)
      end

      def validate_pipeline_prompts(config)
        return if config.pipeline.empty?

        and_exit = false

        config.pipeline.each do |prompt_id|
          next if prompt_id.nil? || prompt_id.empty?

          prompt_file_path = File.join(config.prompts.dir, "#{prompt_id}.txt")
          unless File.exist?(prompt_file_path)
            STDERR.puts "Error: Prompt ID '#{prompt_id}' does not exist at #{prompt_file_path}"
            and_exit = true
          end
        end

        exit(1) if and_exit
      end

      # Dump configuration to file
      #
      # @param config [AIA::Config] the configuration to dump
      # @param file [String] the file path to dump to
      def dump_config(config, file)
        ext = File.extname(file).downcase

        config_hash = config.to_h

        # Remove runtime keys
        config_hash.delete(:prompt_id)
        config_hash.delete(:dump_file)

        content = case ext
                  when '.yml', '.yaml'
                    require 'yaml'
                    YAML.dump(config_hash.transform_keys(&:to_s))
                  else
                    raise "Unsupported config file format: #{ext}. Use .yml or .yaml"
                  end

        File.write(file, content)
        puts "Config successfully dumped to #{file}"
      end
    end
  end
end
