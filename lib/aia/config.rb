# lib/aia/config.rb
#
# This file contains the configuration settings for the AIA application.
# The Config class is responsible for managing configuration settings
# for the AIA application. It provides methods to parse command-line
# arguments, environment variables, and configuration files.

require 'yaml'
require 'toml-rb'
require 'date'
require 'erb'
require 'optparse'
require 'json'
require 'tempfile'
require 'fileutils'

module AIA
  class Config
    DEFAULT_CONFIG = OpenStruct.new({
      adapter:      'ruby_llm', # 'ruby_llm' or ???
      #
      aia_dir:      File.join(ENV['HOME'], '.aia'),
      config_file:  File.join(ENV['HOME'], '.aia', 'config.yml'),
      out_file:     'temp.md',
      log_file:     File.join(ENV['HOME'], '.prompts', '_prompts.log'),
      context_files: [],
      #
      prompts_dir:  File.join(ENV['HOME'], '.prompts'),
      prompt_extname: PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION,
      #
      roles_prefix: 'roles',
      roles_dir:    File.join(ENV['HOME'], '.prompts', 'roles'),
      role:         '',

      #
      system_prompt: '',

      # Tools
      tools:          '',  # Comma-separated string of loaded tool names (set by adapter)
      allowed_tools:  nil, # nil means all tools are allowed; otherwise an Array of Strings which are the tool names
      rejected_tools: nil, # nil means no tools are rejected
      tool_paths:     [],  # Strings - absolute and relative to tools

      # Flags
      markdown: true,
      shell:    true,
      erb:      true,
      chat:     false,
      clear:    false,
      terse:    false,
      verbose:  false,
      debug:    $DEBUG_ME,
      fuzzy:    false,
      speak:    false,
      append:   false, # Default to not append to existing out_file

      # workflow
      pipeline: [],

      # PromptManager::Prompt Tailoring
      parameter_regex: PromptManager::Prompt.parameter_regex.to_s,

      # LLM tuning parameters
      temperature:          0.7,
      max_tokens:           2048,
      top_p:                1.0,
      frequency_penalty:    0.0,
      presence_penalty:     0.0,

      # Audio Parameters
      voice:                'alloy',
      speak_command:        'afplay', # 'afplay' for audio files on MacOS

      # Image Parameters
      image_size:           '1024x1024',
      image_quality:        'standard',
      image_style:          'vivid',

      # Models
      model:                'gpt-4o-mini',
      speech_model:         'tts-1',
      transcription_model:  'whisper-1',
      embedding_model:      'text-embedding-ada-002',
      image_model:          'dall-e-3',

      # Model Regristery
      refresh:              7, # days between refreshes of model info; 0 means every startup
      last_refresh:         Date.today - 1,

      # Ruby libraries to require for Ruby binding
      require_libs: [],
    }).freeze

    def self.setup
      default_config  = DEFAULT_CONFIG.dup
      cli_config      = cli_options
      envar_config    = envar_options(default_config, cli_config)

      file = envar_config.config_file   unless envar_config.config_file.nil?
      file = cli_config.config_file     unless cli_config.config_file.nil?

      cf_config     = cf_options(file)

      config        = OpenStruct.merge(
                        default_config,
                        cf_config    || {},
                        envar_config || {},
                        cli_config   || {}
                      )

      tailor_the_config(config)
      load_libraries(config)
      load_tools(config)

      if config.dump_file
        dump_config(config, config.dump_file)
      end

      config
    end


    def self.tailor_the_config(config)
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


    def self.load_libraries(config)
      return if config.require_libs.empty?

      exit_on_error = false

      config.require_libs.each do |library|
        begin
          require(library)
        rescue => e
          STDERR.puts "Error loading library '#{library}' #{e.message}"
          exit_on_error = true
        end
      end

      exit(1) if exit_on_error

      config
    end


    def self.load_tools(config)
      return if config.tool_paths.empty?

      require_all_tools(config)

      config
    end


    def self.require_all_tools(config)
      exit_on_error = false

      config.tool_paths.each do |tool_path|
        begin
          # expands path based on PWD
          absolute_tool_path = File.expand_path(tool_path)
          require(absolute_tool_path)
        rescue => e
          STDERR.puts "Error loading tool '#{tool_path}' #{e.message}"
          exit_on_error = true
        end
      end

      exit(1) if exit_on_error
    end


    # envar values are always String object so need other config
    # layers to know the prompter type for each key's value
    def self.envar_options(default, cli_config)
      config = OpenStruct.merge(default, cli_config)
      envars = ENV.keys.select { |key, _| key.start_with?('AIA_') }
      envars.each do |envar|
        key   = envar.sub(/^AIA_/, '').downcase.to_sym
        value = ENV[envar]

        value = case config[key]
                when TrueClass, FalseClass
                  value.downcase == 'true'
                when Integer
                  value.to_i
                when Float
                  value.to_f
                when Array
                  value.split(',').map(&:strip)
                else
                  value # defaults to String
                end
        config[key] = value
      end

      config
    end


    def self.cli_options
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

    def self.create_option_parser(config)
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

    def self.setup_banner(opts)
      opts.banner = "Usage: aia [options] [PROMPT_ID] [CONTEXT_FILE]*\n" +
                    "       aia --chat [PROMPT_ID] [CONTEXT_FILE]*\n" +
                    "       aia --chat [CONTEXT_FILE]*"
    end

    def self.setup_mode_options(opts, config)
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

    def self.setup_adapter_options(opts, config)
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

    def self.setup_model_options(opts, config)
      opts.on("-m MODEL", "--model MODEL", "Name of the LLM model to use") do |model|
        config.model = model
      end

      opts.on("--sm", "--speech_model MODEL", "Speech model to use") do |model|
        config.speech_model = model
      end

      opts.on("--tm", "--transcription_model MODEL", "Transcription model to use") do |model|
        config.transcription_model = model
      end
    end

    def self.setup_file_options(opts, config)
      opts.on("-c", "--config_file FILE", "Load config file") do |file|
        load_config_file(file, config)
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

    def self.setup_prompt_options(opts, config)
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

    def self.setup_ai_parameters(opts, config)
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

    def self.setup_audio_image_options(opts, config)
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

    def self.setup_tool_options(opts, config)
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

    def self.setup_utility_options(opts, config)
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
          - AIA Documentation:     https://github.com/madbomber/aia/blob/main/README.md
          - AIA GitHub Repository: https://github.com/MadBomber/aia
          - PromptManager Docs:    https://github.com/MadBomber/prompt_manager/blob/main/README.md
          - ERB Documentation:     https://rubyapi.org/o/erb
          - RubyLLM Tool Docs:     https://rubyllm.com/guides/tools
          - MCP Client Docs:       https://github.com/patvice/ruby_llm-mcp/blob/main/README.md

        EXTRA

        exit
      end
    end

    def self.list_available_models(query)
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

    def self.load_config_file(file, config)
      if File.exist?(file)
        ext = File.extname(file).downcase
        content = File.read(file)

        # Process ERB if filename ends with .erb
        if file.end_with?('.erb')
          content = ERB.new(content).result
          file = file.chomp('.erb')
          File.write(file, content)
        end

        file_config = case ext
                      when '.yml', '.yaml'
                        YAML.safe_load(content, permitted_classes: [Symbol], symbolize_names: true)
                      when '.toml'
                        TomlRB.parse(content)
                      else
                        raise "Unsupported config file format: #{ext}"
                      end

        file_config.each do |key, value|
          config[key.to_sym] = value
        end
      else
        raise "Config file not found: #{file}"
      end
    end

    def self.process_tools_option(a_path_list, config)
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

    def self.process_allowed_tools_option(tools_list, config)
      config.allowed_tools ||= []
      if tools_list.empty?
        STDERR.puts "No list of tool names provided for --allowed_tools option"
        exit 1
      else
        config.allowed_tools += tools_list.split(',').map(&:strip)
        config.allowed_tools.uniq!
      end
    end

    def self.process_rejected_tools_option(tools_list, config)
      config.rejected_tools ||= []
      if tools_list.empty?
        STDERR.puts "No list of tool names provided for --rejected_tools option"
        exit 1
      else
        config.rejected_tools += tools_list.split(',').map(&:strip)
        config.rejected_tools.uniq!
      end
    end

    def self.process_stdin_content
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

    def self.process_prompt_id_from_args(config, remaining_args)
      return if remaining_args.empty?

      maybe_id = remaining_args.first
      maybe_id_plus = File.join(config.prompts_dir, maybe_id + config.prompt_extname)

      if AIA.bad_file?(maybe_id) && AIA.good_file?(maybe_id_plus)
        config.prompt_id = remaining_args.shift
      end
    end

    def self.validate_and_set_context_files(config, remaining_args)
      return if remaining_args.empty?

      bad_files = remaining_args.reject { |filename| AIA.good_file?(filename) }
      if bad_files.any?
        STDERR.puts "Error: The following files do not exist: #{bad_files.join(', ')}"
        exit 1
      end

      config.context_files ||= []
      config.context_files += remaining_args
    end

    def self.handle_executable_prompt(config)
      return unless config.executable_prompt && config.context_files && !config.context_files.empty?

      config.executable_prompt_file = config.context_files.pop
    end

    def self.validate_required_prompt_id(config)
      return unless config.prompt_id.nil? && !config.chat && !config.fuzzy

      STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
      exit 1
    end

    def self.process_role_configuration(config)
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

    def self.handle_fuzzy_search_prompt_id(config)
      return unless config.fuzzy && config.prompt_id.empty?

      # When fuzzy search is enabled but no prompt ID is provided,
      # set a special value to trigger fuzzy search without an initial query
      # SMELL: This feels like a cludge
      config.prompt_id = '__FUZZY_SEARCH__'
    end

    def self.normalize_boolean_flags(config)
      normalize_boolean_flag(config, :chat)
      normalize_boolean_flag(config, :fuzzy)
    end

    def self.normalize_boolean_flag(config, flag)
      return if [TrueClass, FalseClass].include?(config[flag].class)

      config[flag] = if config[flag].nil? || config[flag].empty?
                       false
                     else
                       true
                     end
    end

    def self.handle_completion_script(config)
      return unless config.completion

      generate_completion_script(config.completion)
      exit
    end

    def self.validate_final_prompt_requirements(config)
      # Only require a prompt_id if we're not in chat mode, not using fuzzy search, and no context files
      if !config.chat && !config.fuzzy && (config.prompt_id.nil? || config.prompt_id.empty?) && (!config.context_files || config.context_files.empty?)
        STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
        exit 1
      end

      # If we're in chat mode with context files but no prompt_id, that's valid
      # This is handled implicitly - no action needed
    end

    def self.configure_prompt_manager(config)
      return unless config.parameter_regex

      PromptManager::Prompt.parameter_regex = Regexp.new(config.parameter_regex)
    end

    def self.prepare_pipeline(config)
      return if config.prompt_id.nil? || config.prompt_id.empty? || config.prompt_id == config.pipeline.first

      config.pipeline.prepend config.prompt_id
    end

    def self.validate_pipeline_prompts(config)
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

    def self.parse_remaining_arguments(opt_parser, config)
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


    def self.cf_options(file)
      config = OpenStruct.new

      if File.exist?(file)
        content = read_and_process_config_file(file)
        file_config = parse_config_content(content, File.extname(file).downcase)
        apply_file_config_to_struct(config, file_config)
      else
        STDERR.puts "WARNING:Config file not found: #{file}"
      end

      normalize_last_refresh_date(config)
      config
    end

    def self.read_and_process_config_file(file)
      content = File.read(file)

      # Process ERB if filename ends with .erb
      if file.end_with?('.erb')
        content = ERB.new(content).result
        processed_file = file.chomp('.erb')
        File.write(processed_file, content)
      end

      content
    end

    def self.parse_config_content(content, ext)
      case ext
      when '.yml', '.yaml'
        YAML.safe_load(content, permitted_classes: [Symbol], symbolize_names: true)
      when '.toml'
        TomlRB.parse(content)
      else
        raise "Unsupported config file format: #{ext}"
      end
    end

    def self.apply_file_config_to_struct(config, file_config)
      file_config.each do |key, value|
        config[key] = value
      end
    end

    def self.normalize_last_refresh_date(config)
      return unless config.last_refresh&.is_a?(String)

      config.last_refresh = Date.strptime(config.last_refresh, '%Y-%m-%d')
    end


    def self.generate_completion_script(shell)
      script_path = File.join(File.dirname(__FILE__), "aia_completion.#{shell}")

      if File.exist?(script_path)
        puts File.read(script_path)
      else
        STDERR.puts "ERROR: The shell '#{shell}' is not supported or the completion script is missing."
      end
    end


    def self.dump_config(config, file)
      # Implementation for config dump
      ext = File.extname(file).downcase

      config.last_refresh = config.last_refresh.to_s if config.last_refresh.is_a? Date

      config_hash = config.to_h

      # Remove prompt_id to prevent automatic initial pompting in --chat mode
      config_hash.delete(:prompt_id)

      # Remove dump_file key to prevent automatic exit on next load
      config_hash.delete(:dump_file)

      content = case ext
                when '.yml', '.yaml'
                  YAML.dump(config_hash)
                when '.toml'
                  TomlRB.dump(config_hash)
                else
                  raise "Unsupported config file format: #{ext}"
                end

      File.write(file, content)
      puts "Config successfully dumped to #{file}"
    end
  end
end
