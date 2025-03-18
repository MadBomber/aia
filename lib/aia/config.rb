# lib/aia/config.rb
#
# This file contains the configuration settings for the AIA application.

require 'ostruct'
require 'yaml'
require 'toml-rb'
require 'erb'
require 'optparse'

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  # The Config class is responsible for managing configuration settings
  # for the AIA application. It provides methods to parse command-line
  # arguments, environment variables, and configuration files.
  class Config
    DEFAULT_CONFIG = {
      model: 'openai/gpt-4o-mini',
      out_file: 'temp.md', # Default to temp.md if not specified
      log_file: File.join(ENV['HOME'], '.prompts', 'prompts.log'),
      prompts_dir: ENV['AIA_PROMPTS_DIR'] || File.join(ENV['HOME'], '.prompts'),
      roles_dir: nil, # Will default to prompts_dir/roles
      markdown: true,
      shell: false,
      erb: false,
      chat: false,
      terse: false,
      verbose: false,
      debug: false,
      fuzzy: false,
      next: nil,
      pipeline: [],
      append: false, # Default to not append to existing out_file
      temperature: 0.7,
      max_tokens: 2048,
      top_p: 1.0,
      frequency_penalty: 0.0,
      presence_penalty: 0.0,
      # Image generation parameters
      image_size: '1024x1024',
      image_quality: 'standard',
      image_style: 'vivid',
      # Speech parameters
      speech_model: 'tts-1',
      transcription_model: 'whisper-1',
      voice: 'alloy',
      # Embedding parameters
      embedding_model: 'text-embedding-ada-002',
      # Default speak command
      speak_command: 'afplay' # 'afplay' for audio files
    }.freeze

    # Parses the configuration settings from command-line arguments,
    # environment variables, and configuration files.
    #
    # @param args [Array<String>] the command-line arguments
    # @return [OpenStruct] the configuration object
    def self.parse(args)
      config = OpenStruct.new(DEFAULT_CONFIG)

      # Override with environment variables
      DEFAULT_CONFIG.each_key do |key|
        env_var = "AIA_#{key.to_s.upcase}"
        if ENV.key?(env_var)
          value = ENV[env_var]
          # Convert string to appropriate type
          value = case DEFAULT_CONFIG[key]
                  when TrueClass, FalseClass
                    value.downcase == 'true'
                  when Integer
                    value.to_i
                  when Float
                    value.to_f
                  when Array
                    value.split(',')
                  else
                    value
                  end
          config[key] = value
        end
      end

      # Parse command line options
      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: aia [options] PROMPT_ID [CONTEXT_FILE]*"

        opts.on("--chat", "Begin a chat session after initial prompt") do
          config.chat = true
        end

        opts.on("--model MODEL", "Name of the LLM model to use") do |model|
          config.model = model
        end

        opts.on("--shell", "Process shell commands in prompt") do
          config.shell = true
        end

        opts.on("--erb", "Process ERB in prompt") do
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
                            YAML.safe_load(content, symbolize_names: true)
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

        opts.on("--roles_dir DIR", "Directory containing role files") do |dir|
          config.roles_dir = dir
        end

        opts.on("-r", "--role ROLE_ID", "Role ID to prepend to prompt") do |role|
          config.role = role
        end

        opts.on("-o", "--[no-]out_file [FILE]", "Output file (default: STDOUT)") do |file|
          config.out_file = file ? File.expand_path(file, Dir.pwd) : File.expand_path('temp.md', Dir.pwd)
        end

        opts.on("-a", "--[no-]append", "Append to output file instead of overwriting") do |append|
          config.append = append
        end

        opts.on("-l", "--[no-]log_file [FILE]", "Log file") do |file|
          config.log_file = file
        end

        opts.on("-m", "--[no-]markdown", "Format with Markdown") do |md|
          config.markdown = md
        end

        opts.on("-n", "--next PROMPT_ID", "Next prompt to process") do |next_prompt|
          config.next = next_prompt
        end

        opts.on("--pipeline PROMPTS", "Pipeline of prompts to process") do |pipeline|
          config.pipeline = pipeline.split(',')
        end

        opts.on("-f", "--fuzzy", "Use fuzzy matching for prompt search") do
          config.fuzzy = true
        end

        opts.on("-d", "--debug", "Enable debug output") do
          config.debug = true
        end

        opts.on("-v", "--verbose", "Be verbose") do
          config.verbose = true
        end

        opts.on("--speak", "Speak the response") do
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

        opts.on("--backend BACKEND", "Backend to use (for compatibility)") do |backend|
          config.backend = backend
        end

        opts.on("--dump FILE", "Dump config to file") do |file|
          config.dump_file = file
        end

        opts.on("--completion SHELL", "Show completion script") do |shell|
          config.completion = shell
        end

        opts.on("--version", "Show version") do
          puts AIA::VERSION
          exit
        end

        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit
        end
      end

      # Parse the command line arguments
      remaining_args = opt_parser.parse(args)

      # First remaining arg is the prompt ID
      if remaining_args.empty?
        if config.completion
          # Handle completion script generation
          generate_completion_script(config.completion)
          exit
        elsif config.dump_file
          # Handle config dump
          dump_config(config, config.dump_file)
          exit
        elsif config.chat && config.role
          # For chat mode with a role, use the role as the prompt_id
          # When the role_id is provided, format it as roles/role_id
          # which is the expected format for the prompt_id when referencing a role
          roles = config.roles_dir.split('/').last
          config.prompt_id = "roles/#{config.role}"
        elsif config.chat
          # For chat mode without a role or prompt_id, use an empty prompt_id
          # This will start a chat with no system prompt
          config.prompt_id = ''
        else
          puts "Use -h or --help for help"
          exit
        end
      else
        config.prompt_id = remaining_args.shift
      end

      # Remaining args are context files
      config.context_files = remaining_args unless remaining_args.empty?

      # Set roles_dir default if not specified
      config.roles_dir ||= File.join(config.prompts_dir, 'roles')

      config
    end

    # Generates a shell completion script for the specified shell.
    #
    # @param shell [String] the shell type (e.g., "bash", "zsh", "fish")
    def self.generate_completion_script(shell)
      # Implementation for shell completion script generation
      # This would output a script for bash, zsh, or fish
      puts "# Completion script for #{shell} would be generated here"
    end

    # Dumps the current configuration to a file in the specified format.
    #
    # @param config [OpenStruct] the configuration object
    # @param file [String] the file path to dump the configuration
    def self.dump_config(config, file)
      # Implementation for config dump
      ext = File.extname(file).downcase
      config_hash = config.to_h

      # Remove non-serializable objects
      config_hash.delete_if { |_, v| !v.nil? && !v.is_a?(String) && !v.is_a?(Numeric) && !v.is_a?(TrueClass) && !v.is_a?(FalseClass) && !v.is_a?(Array) && !v.is_a?(Hash) }

      content = case ext
                when '.yml', '.yaml'
                  YAML.dump(config_hash)
                when '.toml'
                  TomlRB.dump(config_hash)
                else
                  raise "Unsupported config file format: #{ext}"
                end

      File.write(file, content)
    end
  end
end
