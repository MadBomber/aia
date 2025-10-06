# lib/aia/config/cli_parser.rb

require 'optparse'
require 'ostruct'

module AIA
  module ConfigModules
    module CLIParser
      class << self
        def cli_options
          config = OpenStruct.new

          begin
            opt_parser = create_option_parser(config)
            opt_parser.parse!
          rescue => e
            STDERR.puts "ERROR: #{e.message}"
            STDERR.puts "       use --help for usage report"
            exit 1
          end

          parse_remaining_arguments(opt_parser, config)
          config
        end

        def create_option_parser(config)
          OptionParser.new do |opts|
            setup_banner(opts)
            setup_mode_options(opts, config)
            setup_adapter_options(opts, config)
            setup_model_options(opts, config)
            setup_file_options(opts, config)
            setup_prompt_options(opts, config)
            setup_ai_parameters(opts, config)
            setup_audio_image_options(opts, config)
            setup_tool_options(opts, config)
            setup_utility_options(opts, config)
          end
        end

        def setup_banner(opts)
          opts.banner = "Usage: aia [options] [PROMPT_ID] [CONTEXT_FILE]*\n" +
                        "       aia --chat [PROMPT_ID] [CONTEXT_FILE]*\n" +
                        "       aia --chat [CONTEXT_FILE]*"
        end

        def setup_mode_options(opts, config)
          opts.on("--chat", "Begin a chat session with the LLM after processing all prompts in the pipeline.") do
            config.chat = true
            puts "Debug: Setting chat mode to true" if config.debug
          end

          opts.on("-f", "--fuzzy", "Use fuzzy matching for prompt search") do
            unless system("which fzf > /dev/null 2>&1")
              STDERR.puts "Error: 'fzf' is not installed. Please install 'fzf' to use the --fuzzy option."
              exit 1
            end
            config.fuzzy = true
          end

          opts.on("--terse", "Adds a special instruction to the prompt asking the AI to keep responses short and to the point") do
            config.terse = true
          end
        end

        def setup_adapter_options(opts, config)
          opts.on("--adapter ADAPTER", "Interface that adapts AIA to the LLM") do |adapter|
            adapter.downcase!
            valid_adapters = %w[ ruby_llm ]  # NOTE: Add additional adapters here when needed
            if valid_adapters.include? adapter
              config.adapter = adapter
            else
              STDERR.puts "ERROR: Invalid adapter #{adapter} must be one of these: #{valid_adapters.join(', ')}"
              exit 1
            end
          end

          opts.on('--available_models [QUERY]', 'List (then exit) available models that match the optional query - a comma separated list of AND components like: openai,mini') do |query|
            list_available_models(query)
          end
        end

        def setup_model_options(opts, config)
          opts.on("-m MODEL", "--model MODEL", "Name of the LLM model(s) to use. Format: MODEL[=ROLE][,MODEL[=ROLE]]...") do |model|
            config.model = parse_models_with_roles(model)
          end

          opts.on("--[no-]consensus", "Enable/disable consensus mode for multi-model responses (default: show individual responses)") do |consensus|
            config.consensus = consensus
          end

          opts.on("--list-roles", "List available role files and exit") do
            list_available_roles
            exit 0
          end

          opts.on("--sm", "--speech_model MODEL", "Speech model to use") do |model|
            config.speech_model = model
          end

          opts.on("--tm", "--transcription_model MODEL", "Transcription model to use") do |model|
            config.transcription_model = model
          end
        end

        def setup_file_options(opts, config)
          opts.on("-c", "--config_file FILE", "Load config file") do |file|
            FileLoader.load_config_file(file, config)
          end

          opts.on("-o", "--[no-]out_file [FILE]", "Output file (default: temp.md)") do |file|
            if file == false  # --no-out_file was used
              config.out_file = nil
            elsif file.nil?   # No argument provided
              config.out_file = 'temp.md'
            else              # File name provided
              config.out_file = File.expand_path(file, Dir.pwd)
            end
          end

          opts.on("-a", "--[no-]append", "Append to output file instead of overwriting") do |append|
            config.append = append
          end

          opts.on("-l", "--[no-]log_file [FILE]", "Log file") do |file|
            config.log_file = file
          end

          opts.on("--md", "--[no-]markdown", "Format with Markdown") do |md|
            config.markdown = md
          end
        end

        def setup_prompt_options(opts, config)
          opts.on("--prompts_dir DIR", "Directory containing prompt files") do |dir|
            config.prompts_dir = dir
          end

          opts.on("--roles_prefix PREFIX", "Subdirectory name for role files (default: roles)") do |prefix|
            config.roles_prefix = prefix
          end

          opts.on("-r", "--role ROLE_ID", "Role ID to prepend to prompt") do |role|
            config.role = role
          end

          opts.on("-n", "--next PROMPT_ID", "Next prompt to process") do |next_prompt|
            config.pipeline ||= []
            config.pipeline << next_prompt
          end

          opts.on("-p PROMPTS", "--pipeline PROMPTS", "Pipeline of comma-seperated prompt IDs to process") do |pipeline|
            config.pipeline ||= []
            config.pipeline += pipeline.split(',').map(&:strip)
          end

          opts.on("-x", "--[no-]exec", "Used to designate an executable prompt file") do |value|
            config.executable_prompt = value
          end

          opts.on("--system_prompt PROMPT_ID", "System prompt ID to use for chat sessions") do |prompt_id|
            config.system_prompt = prompt_id
          end

          opts.on('--regex pattern', 'Regex pattern to extract parameters from prompt text') do |pattern|
            config.parameter_regex = pattern
          end
        end

        def setup_ai_parameters(opts, config)
          opts.on("-t", "--temperature TEMP", Float, "Temperature for text generation") do |temp|
            config.temperature = temp
          end

          opts.on("--max_tokens TOKENS", Integer, "Maximum tokens for text generation") do |tokens|
            config.max_tokens = tokens
          end

          opts.on("--top_p VALUE", Float, "Top-p sampling value") do |value|
            config.top_p = value
          end

          opts.on("--frequency_penalty VALUE", Float, "Frequency penalty") do |value|
            config.frequency_penalty = value
          end

          opts.on("--presence_penalty VALUE", Float, "Presence penalty") do |value|
            config.presence_penalty = value
          end
        end

        def setup_audio_image_options(opts, config)
          opts.on("--speak", "Simple implementation. Uses the speech model to convert text to audio, then plays the audio. Fun with --chat. Supports configuration of speech model and voice.") do
            config.speak = true
          end

          opts.on("--voice VOICE", "Voice to use for speech") do |voice|
            config.voice = voice
          end

          opts.on("--is", "--image_size SIZE", "Image size for image generation") do |size|
            config.image_size = size
          end

          opts.on("--iq", "--image_quality QUALITY", "Image quality for image generation") do |quality|
            config.image_quality = quality
          end

          opts.on("--style", "--image_style STYLE", "Style for image generation") do |style|
            config.image_style = style
          end
        end

        def setup_tool_options(opts, config)
          opts.on("--rq LIBS", "--require LIBS", "Ruby libraries to require for Ruby directive") do |libs|
            config.require_libs ||= []
            config.require_libs += libs.split(',')
          end

          opts.on("--tools PATH_LIST", "Add a tool(s)") do |a_path_list|
            process_tools_option(a_path_list, config)
          end

          opts.on("--at", "--allowed_tools TOOLS_LIST", "Allow only these tools to be used") do |tools_list|
            process_allowed_tools_option(tools_list, config)
          end

          opts.on("--rt", "--rejected_tools TOOLS_LIST", "Reject these tools") do |tools_list|
            process_rejected_tools_option(tools_list, config)
          end
        end

        def setup_utility_options(opts, config)
          opts.on("-d", "--debug", "Enable debug output") do
            config.debug = $DEBUG_ME = true
          end

          opts.on("--no-debug", "Disable debug output") do
            config.debug = $DEBUG_ME = false
          end

          opts.on("-v", "--[no-]verbose", "Be verbose") do |value|
            config.verbose = value
          end

          opts.on("--refresh DAYS", Integer, "Refresh models database interval in days") do |days|
            config.refresh = days || 0
          end

          opts.on("--dump FILE", "Dump config to file") do |file|
            config.dump_file = file
          end

          opts.on("--completion SHELL", "Show completion script for bash|zsh|fish - default is nil") do |shell|
            config.completion = shell
          end

          opts.on("--metrics", "Display token usage in chat mode") do
            config.show_metrics = true
          end

          opts.on("--cost", "Include cost calculations with metrics (requires --metrics)") do
            config.show_cost = true
            config.show_metrics = true  # Automatically enable metrics when cost is requested
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

        def parse_models_with_roles(model_string)
          models = []
          model_counts = Hash.new(0)

          model_string.split(',').each do |spec|
            spec.strip!

            # Validate syntax
            if spec =~ /^=|=$/
              raise ArgumentError, "Invalid model syntax: '#{spec}'. Expected format: MODEL[=ROLE]"
            end

            if spec.include?('=')
              # Explicit role: "model=role" or "provider/model=role"
              model_name, role_name = spec.split('=', 2)
              model_name.strip!
              role_name.strip!

              # Validate role file exists (fail fast)
              validate_role_exists(role_name)

              # Track instance count for duplicates
              model_counts[model_name] += 1
              instance = model_counts[model_name]

              models << {
                model: model_name,
                role: role_name,
                instance: instance,
                internal_id: instance > 1 ? "#{model_name}##{instance}" : model_name
              }
            else
              # No explicit role, will use default from -r/--role
              model_counts[spec] += 1
              instance = model_counts[spec]

              models << {
                model: spec,
                role: nil,
                instance: instance,
                internal_id: instance > 1 ? "#{spec}##{instance}" : spec
              }
            end
          end

          models
        end

        def validate_role_exists(role_id)
          # Get prompts_dir from defaults or environment
          prompts_dir = ENV.fetch('AIA_PROMPTS_DIR', File.join(ENV['HOME'], '.prompts'))
          roles_prefix = ENV.fetch('AIA_ROLES_PREFIX', 'roles')

          # Build role file path
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
          prompts_dir = ENV.fetch('AIA_PROMPTS_DIR', File.join(ENV['HOME'], '.prompts'))
          roles_prefix = ENV.fetch('AIA_ROLES_PREFIX', 'roles')
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

          # Find all .txt files recursively, preserving paths
          Dir.glob("**/*.txt", base: roles_dir)
            .map { |f| f.chomp('.txt') }
            .sort
        end

        def list_available_models(query)
          # SMELL: mostly duplications the code in the vailable_models directive
          #        assumes that the adapter is for the ruby_llm gem
          #        should this be moved to the Utilities class as a common method?

          if query.nil?
            query = []
          else
            query = query.split(',')
          end

          header    = "\nAvailable LLMs"
          header   += " for #{query.join(' and ')}" if query

          puts header + ':'
          puts

          q1 = query.select{|q| q.include?('_to_')}.map{|q| ':'==q[0] ? q[1...] : q}
          q2 = query.reject{|q| q.include?('_to_')}

          counter = 0

          RubyLLM.models.all.each do |llm|
            inputs  = llm.modalities.input.join(',')
            outputs = llm.modalities.output.join(',')
            entry   = "- #{llm.id} (#{llm.provider}) #{inputs} to #{outputs}"

            if query.nil? || query.empty?
              counter += 1
              puts entry
              next
            end

            show_it = true
            q1.each{|q| show_it &&= llm.modalities.send("#{q}?")}
            q2.each{|q| show_it &&= entry.include?(q)}

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

        def parse_remaining_arguments(opt_parser, config)
          args = ARGV.dup

          # Parse the command line arguments
          begin
            config.remaining_args = opt_parser.parse(args)
          rescue OptionParser::InvalidOption => e
            puts e.message
            puts opt_parser
            exit 1
          end
        end

        def process_tools_option(a_path_list, config)
          config.tool_paths ||= []

          if a_path_list.empty?
            STDERR.puts "No list of paths for --tools option"
            exit 1
          else
            paths = a_path_list.split(',').map(&:strip).uniq
          end

          paths.each do |a_path|
            if File.exist?(a_path)
              if File.file?(a_path)
                if  '.rb' == File.extname(a_path)
                  config.tool_paths << a_path
                else
                  STDERR.puts "file should have *.rb extension: #{a_path}"
                  exit 1
                end
              elsif File.directory?(a_path)
                rb_files = Dir.glob(File.join(a_path, '*.rb'))
                config.tool_paths += rb_files
              end
            else
              STDERR.puts "file/dir path is not valid: #{a_path}"
              exit 1
            end
          end

          config.tool_paths.uniq!
        end

        def process_allowed_tools_option(tools_list, config)
          config.allowed_tools ||= []
          if tools_list.empty?
            STDERR.puts "No list of tool names provided for --allowed_tools option"
            exit 1
          else
            config.allowed_tools += tools_list.split(',').map(&:strip)
            config.allowed_tools.uniq!
          end
        end

        def process_rejected_tools_option(tools_list, config)
          config.rejected_tools ||= []
          if tools_list.empty?
            STDERR.puts "No list of tool names provided for --rejected_tools option"
            exit 1
          else
            config.rejected_tools += tools_list.split(',').map(&:strip)
            config.rejected_tools.uniq!
          end
        end
      end
    end
  end
end
