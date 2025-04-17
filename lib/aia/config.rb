# lib/aia/config.rb
#
# This file contains the configuration settings for the AIA application.
# The Config class is responsible for managing configuration settings
# for the AIA application. It provides methods to parse command-line
# arguments, environment variables, and configuration files.

require 'yaml'
require 'toml-rb'
require 'erb'
require 'optparse'


module AIA
  class Config
    DEFAULT_CONFIG = {
      aia_dir:      File.join(ENV['HOME'], '.aia'),
      config_file:  File.join(ENV['HOME'], '.aia', 'config.yml'),
      out_file:     'temp.md',
      log_file:     File.join(ENV['HOME'], '.prompts', '_prompts.log'),
      prompts_dir:  File.join(ENV['HOME'], '.prompts'),
      roles_prefix: 'roles',
      roles_dir:    File.join(ENV['HOME'], '.prompts', 'roles'),
      role:         '',
      system_prompt: '',

      # Flags
      markdown: true,
      shell:    false,
      erb:      false,
      chat:     false,
      clear:    false,
      terse:    false,
      verbose:  false,
      debug:    $DEBUG_ME,
      fuzzy:    false,
      speak:    false,
      append:   false, # Default to not append to existing out_file

      # workflow
      next:     nil,
      pipeline: [],

      # PromptManager::Prompt Tailoring

      parameter_regex: PromptManager::Prompt.parameter_regex.to_s,

      # LLM tuning parameters
      temperature:          0.7,
      max_tokens:           2048,
      top_p:                1.0,
      frequency_penalty:    0.0,
      presence_penalty:     0.0,
      image_size:           '1024x1024',
      image_quality:        'standard',
      image_style:          'vivid',
      model:                'gpt-4o-mini',
      speech_model:         'tts-1',
      transcription_model:  'whisper-1',
      voice:                'alloy',

      # Embedding parameters
      embedding_model: 'text-embedding-ada-002',

      # Default speak command
      speak_command: 'afplay', # 'afplay' for audio files

      # Ruby libraries to require for Ruby binding
      require_libs: [],
    }.freeze


    def self.setup
      default_config  = OpenStruct.new(DEFAULT_CONFIG)
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
    end


    def self.tailor_the_config(config)
      unless config.role.empty?
        unless config.roles_prefix.empty?
          unless config.role.start_with?(config.roles_prefix)
            config.role.prepend "#{config.roles_prefix}/"
          end
        end
      end

      config.roles_dir ||= File.join(config.prompts_dir, config.roles_prefix)

      if config.prompt_id.nil? || config.prompt_id.empty?
        if !config.role.nil? || !config.role.empty?
          config.prompt_id = config.role
          config.role      = ''
        end
      end

      if config.fuzzy && config.prompt_id.empty?
        # When fuzzy search is enabled but no prompt ID is provided,
        # set a special value to trigger fuzzy search without an initial query
        # SMELL: This feels like a cludge
        config.prompt_id = '__FUZZY_SEARCH__'
      end

      unless [TrueClass, FalseClass].include?(config.chat.class)
        if config.chat.nil? || config.chat.empty?
          config.chat = false
        else
          config.chat = true
        end
      end

      unless [TrueClass, FalseClass].include?(config.fuzzy.class)
        if config.fuzzy.nil? || config.fuzzy.empty?
          config.fuzzy = false
        else
          config.fuzzy = true
        end
      end

      and_exit = false

      if config.completion
        generate_completion_script(config.completion)
        and_exit = true
      end

      if config.dump_file
        dump_config(config, config.dump_file)
        and_exit = true
      end

      exit if and_exit

      # Only require a prompt_id if we're not in chat mode, not using fuzzy search, and no context files
      if !config.chat && !config.fuzzy && config.prompt_id.empty? && (!config.context_files || config.context_files.empty?)
        STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
        exit 1
      end
      
      # If we're in chat mode with context files but no prompt_id, that's valid
      if config.chat && config.prompt_id.empty? && config.context_files && !config.context_files.empty?
        # This is a valid use case - no action needed
      end

      # Tailor the PromptManager::Prompt
      if config.parameter_regex
        PromptManager::Prompt.parameter_regex = Regexp.new(config.parameter_regex)
      end

      config
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

      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: aia [options] [PROMPT_ID] [CONTEXT_FILE]*\n" +
                     "       aia --chat [PROMPT_ID] [CONTEXT_FILE]*\n" +
                     "       aia --chat [CONTEXT_FILE]*"

        opts.on("--chat", "Begin a chat session with the LLM after the initial prompt response; will set --no-out_file so that the LLM response comes to STDOUT.") do
          config.chat = true
          puts "Debug: Setting chat mode to true" if config.debug
        end

        opts.on("-m MODEL", "--model MODEL", "Name of the LLM model to use") do |model|
          config.model = model
        end

        opts.on("--shell", "Enables `aia` to access your terminal's shell environment from inside the prompt text, allowing for dynamic content insertion using system environment variables and shell commands. Includes safety features to confirm or block dangerous commands.") do
          config.shell = true
        end

        opts.on("--erb", "Turns the prompt text file into a fully functioning ERB template, allowing for embedded Ruby code processing within the prompt text. This enables dynamic content generation and complex logic within prompts.") do
          config.erb = true
        end

        opts.on("--terse", "Add terse instruction to prompt") do
          config.terse = true
        end

        opts.on("-c", "--config_file FILE", "Load config file") do |file|
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

        opts.on("-p", "--prompts_dir DIR", "Directory containing prompt files") do |dir|
          config.prompts_dir = dir
        end

        opts.on("--roles_prefix PREFIX", "Subdirectory name for role files (default: roles)") do |prefix|
          config.roles_prefix = prefix
        end

        opts.on("-r", "--role ROLE_ID", "Role ID to prepend to prompt") do |role|
          config.role = role
        end

        opts.on('--regex pattern', 'Regex pattern to extract parameters from prompt text') do |pattern|
          config.parameter_regex = pattern
        end

        opts.on("-o", "--[no-]out_file [FILE]", "Output file (default: temp.md)") do |file|
          config.out_file = file ? File.expand_path(file, Dir.pwd) : 'temp.md'
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

        opts.on("-n", "--next PROMPT_ID", "Next prompt to process") do |next_prompt|
          config.next = next_prompt
        end

        opts.on("--pipeline PROMPTS", "Pipeline of prompts to process") do |pipeline|
          config.pipeline = pipeline.split(',')
        end

        opts.on("-f", "--fuzzy", "Use fuzzy matching for prompt search") do
          unless system("which fzf > /dev/null 2>&1")
            STDERR.puts "Error: 'fzf' is not installed. Please install 'fzf' to use the --fuzzy option."
            exit 1
          end
          config.fuzzy = true
        end

        opts.on("-d", "--debug", "Enable debug output") do
          config.debug = $DEBUG_ME = true
        end

        opts.on("--no-debug", "Disable debug output") do
          config.debug = $DEBUG_ME = false
        end

        opts.on("-v", "--verbose", "Be verbose") do
          config.verbose = true
        end

        opts.on("--speak", "Simple implementation. Uses the speech model to convert text to audio, then plays the audio. Fun with --chat. Supports configuration of speech model and voice.") do
          config.speak = true
        end

        opts.on("--voice VOICE", "Voice to use for speech") do |voice|
          config.voice = voice
        end

        opts.on("--sm", "--speech_model MODEL", "Speech model to use") do |model|
          config.speech_model = model
        end

        opts.on("--tm", "--transcription_model MODEL", "Transcription model to use") do |model|
          config.transcription_model = model
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

        opts.on("--system_prompt PROMPT_ID", "System prompt ID to use for chat sessions") do |prompt_id|
          config.system_prompt = prompt_id
        end

        # AI model parameters
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
          puts opts
          exit
        end

        opts.on("--rq LIBS", "Ruby libraries to require for Ruby directive") do |libs|
          config.require_libs = libs.split(',')
        end
      end

      args = ARGV.dup

      # Parse the command line arguments
      begin
        remaining_args = opt_parser.parse(args)
      rescue OptionParser::InvalidOption => e
        puts e.message
        puts opt_parser
        exit 1
      end

      # Handle remaining args
      unless remaining_args.empty?
        # If in chat mode and all args are existing files, treat them all as context files
        if config.chat && remaining_args.all? { |arg| File.exist?(arg) }
          config.context_files = remaining_args
        # If first arg is empty string and we're in chat mode, treat all args as context files
        elsif config.chat && remaining_args.first == ""
          remaining_args.shift # Remove the empty string
          config.context_files = remaining_args unless remaining_args.empty?
        else
          # First remaining arg is the prompt ID
          config.prompt_id = remaining_args.shift
          
          # Remaining args are context files
          config.context_files = remaining_args unless remaining_args.empty?
        end
      end


      config
    end


    def self.cf_options(file)
      config  = OpenStruct.new

      if File.exist?(file)
        ext     = File.extname(file).downcase
        content = File.read(file)

        # Process ERB if filename ends with .erb
        if file.end_with?('.erb')
          content = ERB.new(content).result
          file    = file.chomp('.erb')
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
          config[key] = value
        end
      else
        STDERR.puts "WARNING:Config file not found: #{file}"
      end

      config
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
      config_hash = config.to_h

      # Remove non-serializable objects
      config_hash.delete_if { |_, v| !v.nil? && !v.is_a?(String) && !v.is_a?(Numeric) && !v.is_a?(TrueClass) && !v.is_a?(FalseClass) && !v.is_a?(Array) && !v.is_a?(Hash) }

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
