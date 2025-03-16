#
# This file handles prompt management for the AIA application.

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'
require 'erb'

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  # The PromptHandler class is responsible for managing and processing
  # prompts within the AIA application. It interacts with the PromptManager
  # to retrieve and process prompts.
  class PromptHandler
    # Initializes a new PromptHandler with the given configuration.
    #
    # @param config [OpenStruct] the configuration object
    def initialize(config)
      @config = config
      @prompts_dir = config.prompts_dir
      @roles_dir = config.roles_dir

      # Initialize PromptManager with the FileSystemAdapter
      PromptManager::Prompt.storage_adapter =
        PromptManager::Storage::FileSystemAdapter.config do |config|
          config.prompts_dir = @prompts_dir
          config.prompt_extension = '.txt'  # default
          config.params_extension = '.json' # default
        end.new
    end

    # Retrieves and processes a prompt by its ID, optionally prepending a role.
    #
    # @param prompt_id [String] the ID of the prompt to retrieve
    # @param role_id [String, nil] the ID of the role to prepend (optional)
    # @return [String] the processed prompt text
    def get_prompt(prompt_id, role_id = nil)
      # Get the prompt using the gem's functionality
      prompt = PromptManager::Prompt.get(id: prompt_id)

      if role_id
        # Get the role prompt
        role_prompt = PromptManager::Prompt.get(id: role_id)
        # Prepend role to prompt
        prompt.text = "#{role_prompt.text}
#{prompt.text}"
      end

      # Process the prompt using the gem's functionality
      process_prompt(prompt)
    end

    # Processes a given prompt, handling shell commands, ERB, and directives.
    #
    # @param prompt [PromptManager::Prompt, String] the prompt to process
    # @return [String] the processed prompt text
    def process_prompt(prompt)
      # Deep copy the prompt to avoid modifying the original
      if prompt.is_a?(PromptManager::Prompt)
        # Process shell commands if enabled
        if @config.shell
          prompt.text = prompt.text.gsub(/$((.*?))/) { `#{Regexp.last_match(1)}`.chomp }
        end

        # Process ERB if enabled
        if @config.erb
          prompt.text = ERB.new(prompt.text).result(binding)
        end

        # Build the prompt with parameters
        text = prompt.to_s

        # Process directives after building the prompt
        directives = prompt.directives
        text = process_collected_directives(text, directives)

        # Add terse instruction if requested
        if @config.terse
          text += "

Please be terse in your response."
        end

        text
      else
        # Just a plain text prompt
        text = prompt.dup

        # Process shell commands if enabled
        if @config.shell
          text = text.gsub(/$((.*?))/) { `#{Regexp.last_match(1)}`.chomp }
        end

        # Process ERB if enabled
        if @config.erb
          text = ERB.new(text).result(binding)
        end

        # Add terse instruction if requested
        if @config.terse
          text += "

Please be terse in your response."
        end

        text
      end
    end

    private

    # Processes collected directives within the prompt text, executing
    # commands or including files as specified.
    #
    # @param text [String] the prompt text containing directives
    # @param directives [Hash] the directives to process
    # @return [String] the processed text with directives applied
    def process_collected_directives(text, directives)
      directives.each do |directive, args|
        case directive
        when "config"
          # Process config directive
          key, value = args.split(/\s*=\s*/, 2)
          @config[key.strip.to_sym] = parse_value(value.strip)
        when "include"
          # Include another file
          file_path = args.strip
          if File.exist?(file_path)
            # Replace the directive line with file contents
            text = text.gsub(%r{//include #{Regexp.escape(args)}}, File.read(file_path))
          else
            # Replace with error message
            text = text.gsub(%r{//include #{Regexp.escape(args)}}, "# Error: File not found: #{file_path}")
          end
        when "shell"
          # Execute shell command
          cmd_output = `#{args}`.chomp
          # Replace the directive line with command output
          text = text.gsub(%r{//shell #{Regexp.escape(args)}}, cmd_output)
        when "ruby"
          # Execute Ruby code
          result = eval(args)
          # Replace the directive line with result
          text = text.gsub(%r{//ruby #{Regexp.escape(args)}}, result.to_s)
        when "next"
          # Set next prompt
          @config.next = args.strip
        when "pipeline"
          # Set pipeline
          @config.pipeline = args.strip.split(',')
        end
      end

      text
    end

    # Parses a value from a string, converting it to the appropriate type
    # (e.g., boolean, integer, array).
    #
    # @param value [String] the value to parse
    # @return [Object] the parsed value
    def parse_value(value)
      case value.downcase
      when 'true'
        true
      when 'false'
        false
      when /^\d+$/
        value.to_i
      when /^\d+\.\d+$/
        value.to_f
      when /^\[.*\]$/
        value[1..-2].split(',').map(&:strip)
      else
        value
      end
    end
  end
end
