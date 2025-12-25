# frozen_string_literal: true

# lib/aia/config/cli_parser.rb
#
# Parses command-line arguments and returns a hash of overrides
# for the Config class.

require 'optparse'
require_relative 'model_spec'

module AIA
  module CLIParser
    class << self
      # Parse CLI arguments and return a hash of overrides
      #
      # @return [Hash] configuration overrides from CLI
      def parse
        options = {}

        begin
          parser = create_option_parser(options)
          parser.parse!
        rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
          STDERR.puts "ERROR: #{e.message}"
          STDERR.puts "       use --help for usage report"
          exit 1
        end

        # Store remaining args for prompt_id and context files
        options[:remaining_args] = ARGV.dup

        options
      end

      private

      def create_option_parser(options)
        OptionParser.new do |opts|
          setup_banner(opts)
          setup_mode_options(opts, options)
          setup_adapter_options(opts, options)
          setup_model_options(opts, options)
          setup_file_options(opts, options)
          setup_prompt_options(opts, options)
          setup_ai_parameters(opts, options)
          setup_audio_image_options(opts, options)
          setup_tool_options(opts, options)
          setup_utility_options(opts, options)
        end
      end

      def setup_banner(opts)
        opts.banner = "Usage: aia [options] [PROMPT_ID] [CONTEXT_FILE]*\n" +
                      "       aia --chat [PROMPT_ID] [CONTEXT_FILE]*\n" +
                      "       aia --chat [CONTEXT_FILE]*"
      end

      def setup_mode_options(opts, options)
        opts.on("--chat", "Begin a chat session with the LLM after processing all prompts in the pipeline.") do
          options[:chat] = true
        end

        opts.on("-f", "--fuzzy", "Use fuzzy matching for prompt search") do
          unless system("which fzf > /dev/null 2>&1")
            STDERR.puts "Error: 'fzf' is not installed. Please install 'fzf' to use the --fuzzy option."
            exit 1
          end
          options[:fuzzy] = true
        end

        opts.on("--terse", "Adds a special instruction to the prompt asking the AI to keep responses short and to the point") do
          options[:terse] = true
        end
      end

      def setup_adapter_options(opts, options)
        opts.on("--adapter ADAPTER", "Interface that adapts AIA to the LLM") do |adapter|
          adapter.downcase!
          valid_adapters = %w[ruby_llm]
          if valid_adapters.include?(adapter)
            options[:adapter] = adapter
          else
            STDERR.puts "ERROR: Invalid adapter #{adapter} must be one of these: #{valid_adapters.join(', ')}"
            exit 1
          end
        end

        opts.on('--available-models [QUERY]', 'List (then exit) available models that match the optional query') do |query|
          list_available_models(query)
        end
      end

      def setup_model_options(opts, options)
        opts.on("-m MODEL", "--model MODEL", "Name of the LLM model(s) to use. Format: MODEL[=ROLE][,MODEL[=ROLE]]...") do |model_string|
          options[:models] = parse_models_with_roles(model_string)
        end

        opts.on("--[no-]consensus", "Enable/disable consensus mode for multi-model responses") do |consensus|
          options[:consensus] = consensus
        end

        opts.on("--list-roles", "List available role files and exit") do
          list_available_roles
          exit 0
        end

        opts.on("--sm", "--speech-model MODEL", "Speech model to use") do |model|
          options[:speech_model] = model
        end

        opts.on("--tm", "--transcription-model MODEL", "Transcription model to use") do |model|
          options[:transcription_model] = model
        end
      end

      def setup_file_options(opts, options)
        opts.on("-c", "--config-file FILE", "Load additional config file") do |file|
          options[:extra_config_file] = file
        end

        opts.on("-o", "--[no-]output [FILE]", "Output file (default: temp.md)") do |file|
          if file == false
            options[:output] = nil
          elsif file.nil?
            options[:output] = 'temp.md'
          else
            options[:output] = File.expand_path(file, Dir.pwd)
          end
        end

        opts.on("-a", "--[no-]append", "Append to output file instead of overwriting") do |append|
          options[:append] = append
        end

        opts.on("--[no-]history-file [FILE]", "Conversation history file") do |file|
          options[:history_file] = file
        end

        opts.on("--md", "--[no-]markdown", "Format with Markdown") do |md|
          options[:markdown] = md
        end
      end

      def setup_prompt_options(opts, options)
        opts.on("--prompts-dir DIR", "Directory containing prompt files") do |dir|
          options[:prompts_dir] = dir
        end

        opts.on("--roles-prefix PREFIX", "Subdirectory name for role files (default: roles)") do |prefix|
          options[:roles_prefix] = prefix
        end

        opts.on("-r", "--role ROLE_ID", "Role ID to prepend to prompt") do |role|
          options[:role] = role
        end

        opts.on("-n", "--next PROMPT_ID", "Next prompt to process") do |next_prompt|
          options[:pipeline] ||= []
          options[:pipeline] << next_prompt
        end

        opts.on("-p PROMPTS", "--pipeline PROMPTS", "Pipeline of comma-separated prompt IDs to process") do |pipeline|
          options[:pipeline] ||= []
          options[:pipeline] += pipeline.split(',').map(&:strip)
        end

        opts.on("-x", "--[no-]exec", "Used to designate an executable prompt file") do |value|
          options[:executable_prompt] = value
        end

        opts.on("--system-prompt PROMPT_ID", "System prompt ID to use for chat sessions") do |prompt_id|
          options[:system_prompt] = prompt_id
        end

        opts.on('--regex PATTERN', 'Regex pattern to extract parameters from prompt text') do |pattern|
          options[:parameter_regex] = pattern
        end
      end

      def setup_ai_parameters(opts, options)
        opts.on("-t", "--temperature TEMP", Float, "Temperature for text generation") do |temp|
          options[:temperature] = temp
        end

        opts.on("--max-tokens TOKENS", Integer, "Maximum tokens for text generation") do |tokens|
          options[:max_tokens] = tokens
        end

        opts.on("--top-p VALUE", Float, "Top-p sampling value") do |value|
          options[:top_p] = value
        end

        opts.on("--frequency-penalty VALUE", Float, "Frequency penalty") do |value|
          options[:frequency_penalty] = value
        end

        opts.on("--presence-penalty VALUE", Float, "Presence penalty") do |value|
          options[:presence_penalty] = value
        end
      end

      def setup_audio_image_options(opts, options)
        opts.on("--speak", "Convert text to audio and play it") do
          options[:speak] = true
        end

        opts.on("--voice VOICE", "Voice to use for speech") do |voice|
          options[:voice] = voice
        end

        opts.on("--is", "--image-size SIZE", "Image size for image generation") do |size|
          options[:image_size] = size
        end

        opts.on("--iq", "--image-quality QUALITY", "Image quality for image generation") do |quality|
          options[:image_quality] = quality
        end

        opts.on("--style", "--image-style STYLE", "Style for image generation") do |style|
          options[:image_style] = style
        end
      end

      def setup_tool_options(opts, options)
        opts.on("--rq LIBS", "--require LIBS", "Ruby libraries to require for Ruby directive") do |libs|
          options[:require_libs] ||= []
          options[:require_libs] += libs.split(',')
        end

        opts.on("--tools PATH_LIST", "Add tool(s) by path") do |path_list|
          options[:tool_paths] = process_tools_paths(path_list)
        end

        opts.on("--at", "--allowed-tools TOOLS_LIST", "Allow only these tools to be used") do |tools_list|
          options[:allowed_tools] ||= []
          options[:allowed_tools] += tools_list.split(',').map(&:strip)
        end

        opts.on("--rt", "--rejected-tools TOOLS_LIST", "Reject these tools") do |tools_list|
          options[:rejected_tools] ||= []
          options[:rejected_tools] += tools_list.split(',').map(&:strip)
        end
      end

      def setup_utility_options(opts, options)
        opts.on("-d", "--debug", "Enable debug output and set all loggers to DEBUG level") do
          options[:debug] = true
          options[:log_level_override] = 'debug'
          $DEBUG_ME = true
        end

        opts.on("--no-debug", "Disable debug output") do
          options[:debug] = false
          $DEBUG_ME = false
        end

        opts.on("--info", "Set all loggers to INFO level") do
          options[:log_level_override] = 'info'
        end

        opts.on("--warn", "Set all loggers to WARN level") do
          options[:log_level_override] = 'warn'
        end

        opts.on("--error", "Set all loggers to ERROR level") do
          options[:log_level_override] = 'error'
        end

        opts.on("--fatal", "Set all loggers to FATAL level") do
          options[:log_level_override] = 'fatal'
        end

        opts.on("--log-to FILE", "Direct all loggers to FILE") do |file|
          options[:log_file_override] = file
        end

        opts.on("-v", "--[no-]verbose", "Be verbose") do |value|
          options[:verbose] = value
        end

        opts.on("--refresh DAYS", Integer, "Refresh models database interval in days") do |days|
          options[:refresh] = days || 0
        end

        opts.on("--dump FILE", "Dump config to file") do |file|
          options[:dump_file] = file
        end

        opts.on("--completion SHELL", "Show completion script for bash|zsh|fish") do |shell|
          options[:completion] = shell
        end

        opts.on("--metrics", "Display token usage in chat mode") do
          options[:metrics] = true
        end

        opts.on("--cost", "Include cost calculations with metrics") do
          options[:cost] = true
          options[:metrics] = true  # --cost implies --metrics
        end

        opts.on("--mcp FILE", "Load MCP server(s) from JSON file (can be used multiple times)") do |file|
          options[:mcp_files] ||= []
          options[:mcp_files] << file
        end

        opts.on("--no-mcp", "Disable all MCP server processing") do
          options[:no_mcp] = true
        end

        opts.on("--version", "Show version") do
          puts AIA::VERSION
          exit
        end

        opts.on("-h", "--help", "Prints this help") do
          puts <<~HELP

            AIA your AI Assistant
              - designed for generative AI workflows,
              - effortlessly manage AI prompts,
              - integrate seamlessly with shell and embedded Ruby (ERB),
              - run batch processes,
              - engage in interactive chats,
              - with user defined directives, tools and MCP clients.

          HELP

          puts opts

          puts <<~EXTRA

            Explore Further:
            - AIA Report an Issue:   https://github.com/MadBomber/aia/issues
            - AIA Documentation:     https://github.com/MadBomber/aia/blob/main/README.md
            - AIA GitHub Repository: https://github.com/MadBomber/aia
            - PromptManager Docs:    https://github.com/MadBomber/prompt_manager/blob/main/README.md
            - ERB Documentation:     https://rubyapi.org/o/erb
            - RubyLLM Tool Docs:     https://rubyllm.com/guides/tools
            - MCP Client Docs:       https://github.com/patvice/ruby_llm-mcp/blob/main/README.md

          EXTRA

          exit
        end
      end

      # Parse model string into array of ModelSpec-compatible hashes
      #
      # @param model_string [String] comma-separated models with optional roles
      # @return [Array<Hash>] array of model specs
      def parse_models_with_roles(model_string)
        models = []
        model_counts = Hash.new(0)

        model_string.split(',').each do |spec|
          spec.strip!

          if spec =~ /^=|=$/
            raise ArgumentError, "Invalid model syntax: '#{spec}'. Expected format: MODEL[=ROLE]"
          end

          if spec.include?('=')
            model_name, role_name = spec.split('=', 2)
            model_name.strip!
            role_name.strip!

            validate_role_exists(role_name)

            model_counts[model_name] += 1
            instance = model_counts[model_name]

            models << {
              name: model_name,
              role: role_name,
              instance: instance,
              internal_id: instance > 1 ? "#{model_name}##{instance}" : model_name
            }
          else
            model_counts[spec] += 1
            instance = model_counts[spec]

            models << {
              name: spec,
              role: nil,
              instance: instance,
              internal_id: instance > 1 ? "#{spec}##{instance}" : spec
            }
          end
        end

        models
      end

      def validate_role_exists(role_id)
        prompts_dir = ENV.fetch('AIA_PROMPTS__DIR', File.join(ENV['HOME'], '.prompts'))
        roles_prefix = ENV.fetch('AIA_PROMPTS__ROLES_PREFIX', 'roles')

        unless role_id.start_with?(roles_prefix)
          role_id = "#{roles_prefix}/#{role_id}"
        end

        role_file_path = File.join(prompts_dir, "#{role_id}.txt")

        unless File.exist?(role_file_path)
          available_roles = list_available_role_names(prompts_dir, roles_prefix)

          error_msg = "Role file not found: #{role_file_path}\n\n"

          if available_roles.empty?
            error_msg += "No roles directory found at #{File.join(prompts_dir, roles_prefix)}\n"
            error_msg += "Create the directory and add role files to use this feature."
          else
            error_msg += "Available roles:\n"
            error_msg += available_roles.map { |r| "  - #{r}" }.join("\n")
            error_msg += "\n\nCreate the role file or use an existing role."
          end

          raise ArgumentError, error_msg
        end
      end

      def list_available_roles
        prompts_dir = ENV.fetch('AIA_PROMPTS__DIR', File.join(ENV['HOME'], '.prompts'))
        roles_prefix = ENV.fetch('AIA_PROMPTS__ROLES_PREFIX', 'roles')
        roles_dir = File.join(prompts_dir, roles_prefix)

        if Dir.exist?(roles_dir)
          roles = list_available_role_names(prompts_dir, roles_prefix)

          if roles.empty?
            puts "No role files found in #{roles_dir}"
            puts "Create .txt files in this directory to define roles."
          else
            puts "Available roles in #{roles_dir}:"
            roles.each { |role| puts "  - #{role}" }
          end
        else
          puts "No roles directory found at #{roles_dir}"
          puts "Create this directory and add role files to use roles."
        end
      end

      def list_available_role_names(prompts_dir, roles_prefix)
        roles_dir = File.join(prompts_dir, roles_prefix)
        return [] unless Dir.exist?(roles_dir)

        Dir.glob("**/*.txt", base: roles_dir)
          .map { |f| f.chomp('.txt') }
          .sort
      end

      def list_available_models(query)
        require 'ruby_llm'

        if query.nil?
          query = []
        else
          query = query.split(',')
        end

        header = "\nAvailable LLMs"
        header += " for #{query.join(' and ')}" if query.any?

        puts header + ':'
        puts

        q1 = query.select { |q| q.include?('_to_') }.map { |q| q[0] == ':' ? q[1..] : q }
        q2 = query.reject { |q| q.include?('_to_') }

        counter = 0

        RubyLLM.models.all.each do |llm|
          inputs = llm.modalities.input.join(',')
          outputs = llm.modalities.output.join(',')
          entry = "- #{llm.id} (#{llm.provider}) #{inputs} to #{outputs}"

          if query.nil? || query.empty?
            counter += 1
            puts entry
            next
          end

          show_it = true
          q1.each { |q| show_it &&= llm.modalities.send("#{q}?") }
          q2.each { |q| show_it &&= entry.include?(q) }

          if show_it
            counter += 1
            puts entry
          end
        end

        puts if counter > 0
        puts "#{counter} LLMs matching your query"
        puts

        exit
      end

      def process_tools_paths(path_list)
        paths = []

        if path_list.empty?
          STDERR.puts "No list of paths for --tools option"
          exit 1
        end

        path_list.split(',').map(&:strip).uniq.each do |a_path|
          if File.exist?(a_path)
            if File.file?(a_path)
              if '.rb' == File.extname(a_path)
                paths << a_path
              else
                STDERR.puts "file should have *.rb extension: #{a_path}"
                exit 1
              end
            elsif File.directory?(a_path)
              rb_files = Dir.glob(File.join(a_path, '*.rb'))
              paths += rb_files
            end
          else
            STDERR.puts "file/dir path is not valid: #{a_path}"
            exit 1
          end
        end

        paths.uniq
      end
    end
  end
end
