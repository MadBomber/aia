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
                      "       aia [options] --chat [PROMPT_ID] [CONTEXT_FILE]*"
      end

      def setup_mode_options(opts, options)
        opts.separator "\nMode Options:"

        opts.on("--chat", "Begin a chat session with the LLM after processing all prompts in the pipeline") do
          options[:chat] = true
        end

        opts.on("-f", "--fuzzy", "Use fuzzy matching for prompt search") do
          unless system("which fzf > /dev/null 2>&1")
            STDERR.puts "Error: 'fzf' is not installed. Please install 'fzf' to use the --fuzzy option."
            exit 1
          end
          options[:fuzzy] = true
        end

        opts.on("--terse", "[DEPRECATED] No longer supported") do
          warn "Warning: --terse is deprecated and has no effect."
        end
      end

      def setup_model_options(opts, options)
        opts.separator "\nModel Options:"

        opts.on('--available-models [QUERY]', 'List available models matching optional query and exit') do |query|
          list_available_models(query)
        end

        opts.on("-m MODEL", "--model MODEL", "Set LLM model(s) to use. Format: MODEL[=ROLE][,MODEL[=ROLE]]...") do |model_string|
          options[:models] = parse_models_with_roles(model_string)
        end

        opts.on("--[no-]consensus", "Enable/disable consensus mode for multi-model responses") do |consensus|
          options[:consensus] = consensus
        end

        opts.on("--list-roles", "List available roles and exit") do
          list_available_roles
          exit 0
        end

        opts.on("--sm", "--speech-model MODEL", "Set speech model") do |model|
          options[:speech_model] = model
        end

        opts.on("--tm", "--transcription-model MODEL", "Set transcription model") do |model|
          options[:transcription_model] = model
        end
      end

      def setup_file_options(opts, options)
        opts.separator "\nFile & Output Options:"

        opts.on("-c", "--config-file FILE", "Load additional config file") do |file|
          options[:extra_config_file] = file
        end

        opts.on("-o", "--[no-]output [FILE]", "Write response to FILE (default: temp.md; --no-output to disable)") do |file|
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

        opts.on("--[no-]history-file [FILE]", "Set conversation history file path") do |file|
          options[:history_file] = file
        end

        opts.on("--md", "--[no-]markdown", "Enable Markdown formatting") do |md|
          options[:markdown] = md
        end
      end

      def setup_prompt_options(opts, options)
        opts.separator "\nPrompt Options:"

        opts.on("--prompts-dir DIR", "Set directory containing prompt files") do |dir|
          options[:prompts_dir] = dir
        end

        opts.on("--roles-prefix PREFIX", "Set subdirectory name for role files (default: roles)") do |prefix|
          options[:roles_prefix] = prefix
        end

        opts.on("-r", "--role ROLE_ID", "Prepend role to prompt") do |role|
          options[:role] = role
        end

        opts.on("-n", "--next PROMPT_ID", "Set next prompt to process") do |next_prompt|
          options[:pipeline] ||= []
          options[:pipeline] << next_prompt
        end

        opts.on("-p PROMPTS", "--pipeline PROMPTS", "Set pipeline of comma-separated prompt IDs") do |pipeline|
          options[:pipeline] ||= []
          options[:pipeline] += pipeline.split(',').map(&:strip)
        end


        opts.on("--system-prompt PROMPT_ID", "Set system prompt for chat sessions") do |prompt_id|
          options[:system_prompt] = prompt_id
        end

        opts.on('--regex PATTERN', '[DEPRECATED] Parameter regex (PM v1.0.0 uses ERB parameters)') do |pattern|
          warn "Warning: --regex is deprecated. PM v1.0.0 uses ERB parameters (<%= param %>)."
          options[:parameter_regex] = pattern
        end
      end

      def setup_ai_parameters(opts, options)
        opts.separator "\nGeneration Parameters:"

        opts.on("-t", "--temperature TEMP", Float, "Set temperature for text generation (default: 0.7)") do |temp|
          options[:temperature] = temp
        end

        opts.on("--max-tokens TOKENS", Integer, "Set maximum tokens for text generation (default: 2048)") do |tokens|
          options[:max_tokens] = tokens
        end

        opts.on("--top-p VALUE", Float, "Set top-p sampling value") do |value|
          options[:top_p] = value
        end

        opts.on("--frequency-penalty VALUE", Float, "Set frequency penalty value") do |value|
          options[:frequency_penalty] = value
        end

        opts.on("--presence-penalty VALUE", Float, "Set presence penalty value") do |value|
          options[:presence_penalty] = value
        end
      end

      def setup_audio_image_options(opts, options)
        opts.separator "\nAudio & Image Options:"

        opts.on("--speak", "Convert response to audio and play it") do
          options[:speak] = true
        end

        opts.on("--voice VOICE", "Set voice for speech output (default: alloy)") do |voice|
          options[:voice] = voice
        end

        opts.on("--is", "--image-size SIZE", "Set image size for generation (default: 1024x1024)") do |size|
          options[:image_size] = size
        end

        opts.on("--iq", "--image-quality QUALITY", "Set image quality for generation (default: standard)") do |quality|
          options[:image_quality] = quality
        end

        opts.on("--style", "--image-style STYLE", "Set style for image generation") do |style|
          options[:image_style] = style
        end
      end

      def setup_tool_options(opts, options)
        opts.separator "\nTool & Extension Options:"

        opts.on("--rq LIBS", "--require LIBS", "Require Ruby libraries for Ruby directive") do |libs|
          options[:require_libs] ||= []
          options[:require_libs] += libs.split(',')
        end

        opts.on("--tools PATH_LIST", "Load tool(s) from path") do |path_list|
          options[:tool_paths] = process_tools_paths(path_list)
        end

        opts.on("--at", "--allowed-tools TOOLS_LIST", "Allow only these tools") do |tools_list|
          options[:allowed_tools] ||= []
          options[:allowed_tools] += tools_list.split(',').map(&:strip)
        end

        opts.on("--rt", "--rejected-tools TOOLS_LIST", "Reject these tools from use") do |tools_list|
          options[:rejected_tools] ||= []
          options[:rejected_tools] += tools_list.split(',').map(&:strip)
        end

        opts.on("--list-tools", "List available tools and exit (combine with --mcp-list for MCP tools)") do
          options[:list_tools] = true
        end
      end

      def setup_utility_options(opts, options)
        opts.separator "\nUtility Options:"

        opts.on("--log-level LEVEL", "Set log level (debug|info|warn|error|fatal)") do |level|
          level = level.downcase
          unless %w[debug info warn error fatal].include?(level)
            STDERR.puts "ERROR: Invalid log level '#{level}'. Must be one of: debug, info, warn, error, fatal"
            exit 1
          end
          options[:log_level_override] = level
          if level == 'debug'
            options[:debug] = true
            $DEBUG_ME = true
          end
        end

        opts.on("-d", "--debug", "Enable debug output (shortcut for --log-level debug)") do
          options[:debug] = true
          options[:log_level_override] = 'debug'
          $DEBUG_ME = true
        end

        opts.on("--no-debug", "Disable debug output") do
          options[:debug] = false
          $DEBUG_ME = false
        end

        opts.on("--log-to FILE", "Direct all loggers to FILE") do |file|
          options[:log_file_override] = file
        end

        opts.on("-v", "--[no-]verbose", "Enable verbose output") do |value|
          options[:verbose] = value
        end

        opts.on("--refresh DAYS", Integer, "Set refresh interval (days) for cached models list (default: 7)") do |days|
          options[:refresh] = days || 0
        end

        opts.on("--dump FILE", "Export current configuration to FILE and exit") do |file|
          options[:dump_file] = file
        end

        opts.on("--completion SHELL", "Generate shell completion script (bash|zsh|fish) and exit") do |shell|
          options[:completion] = shell
        end

        opts.on("--tokens", "Display token usage") do
          options[:tokens] = true
        end

        opts.on("--cost", "Display cost calculations (implies --tokens)") do
          options[:cost] = true
          options[:tokens] = true  # --cost implies --tokens
        end

        opts.on("--mcp FILE", "Load MCP server(s) from JSON file (repeatable)") do |file|
          options[:mcp_files] ||= []
          options[:mcp_files] << file
        end

        opts.on("--no-mcp", "Disable all MCP server processing") do
          options[:no_mcp] = true
        end

        opts.on("--mcp-list", "List configured MCP servers and exit") do
          options[:mcp_list] = true
        end

        opts.on("--mu", "--mcp-use NAMES", "Use only these MCP servers (comma-separated)") do |names|
          options[:mcp_use] ||= []
          options[:mcp_use] += names.split(',').map(&:strip)
        end

        opts.on("--ms", "--mcp-skip NAMES", "Skip these named MCP servers (comma-separated)") do |names|
          options[:mcp_skip] ||= []
          options[:mcp_skip] += names.split(',').map(&:strip)
        end

        opts.on("--version", "Show version and exit") do
          puts AIA::VERSION
          exit
        end

        opts.on("-h", "--help", "Show this help and exit") do
          puts <<~HELP

            AIA - Your AI Assistant (v#{AIA::VERSION})
              - Manage AI prompts with embedded directives
              - Integrate with shell and Ruby (ERB) processing
              - Run batch processes and prompt pipelines
              - Engage in interactive chat sessions
              - Use custom tools and MCP servers

          HELP

          puts opts

          puts <<~EXTRA

            Explore Further:
            - AIA GitHub Repository: https://github.com/MadBomber/aia
            - AIA Documentation:     https://madbomber.github.io/aia
            - AIA Changelog:         https://github.com/MadBomber/aia/blob/main/CHANGELOG.md
            - AIA Examples:          https://github.com/MadBomber/aia/tree/main/examples
            - Report an Issue:       https://github.com/MadBomber/aia/issues
            - RubyLLM Documentation: https://rubyllm.com
            - RubyLLM Tool Docs:     https://rubyllm.com/guides/tools
            - PromptManager Docs:    https://madbomber.github.io/prompt_manager
            - ERB Documentation:     https://docs.ruby-lang.org/en/master/ERB.html
            - MCP Specification:     https://modelcontextprotocol.io
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

        role_file_path = File.join(prompts_dir, "#{role_id}.md")

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
            puts "Create .md files in this directory to define roles."
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

        Dir.glob("**/*.md", base: roles_dir)
          .map { |f| f.chomp('.md') }
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
