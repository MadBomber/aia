#
# This file contains the PromptProcessor class for processing prompts.

require_relative 'shell_command_executor'

module AIA
  # The PromptProcessor class is responsible for processing prompts,
  # handling shell commands, ERB, and directives.
  class PromptProcessor
    def initialize(config)
      @config = config
    end

    # Processes a given prompt, handling shell commands, ERB, and directives.
    #
    # @param prompt [PromptManager::Prompt, String] the prompt to process
    # @return [String] the processed prompt text
    def process(prompt)
      if prompt.is_a?(PromptManager::Prompt)
        process_prompt_object(prompt)
      else
        process_plain_text(prompt)
      end
    end

    private

    def process_prompt_object(prompt)
      text = prompt.text.dup

      # Process shell commands if enabled
      text = process_shell_commands(text) if @config.shell

      # Process ERB if enabled
      text = process_erb(text) if @config.erb

      # Process directives
      text = process_directives(text, prompt.directives)

      # Add terse instruction if requested
      text += "\n\nPlease be terse in your response." if @config.terse

      text
    end

    def process_plain_text(text)
      text = text.dup

      # Process shell commands if enabled
      text = process_shell_commands(text) if @config.shell

      # Process ERB if enabled
      text = process_erb(text) if @config.erb

      # Add terse instruction if requested
      text += "\n\nPlease be terse in your response." if @config.terse

      text
    end

    def process_shell_commands(text)
      # There seems to be an issue with the original regex pattern
      # Fixing it to correctly match the $(command) pattern
      text.gsub(/\$\((.*?)\)/) { ShellCommandExecutor.execute_command(Regexp.last_match(1), @config) }
    end

    def process_erb(text)
      ERB.new(text).result(binding)
    end

    def process_directives(text, directives)
      directives.each do |directive, args|
        case directive
        when "config"
          key, value = args.split(/\s*=\s*/, 2)
          @config[key.strip.to_sym] = parse_value(value.strip)
        when "include"
          file_path = args.strip
          if File.exist?(file_path)
            text = text.gsub(%r{//include #{Regexp.escape(args)}}, File.read(file_path))
          else
            text = text.gsub(%r{//include #{Regexp.escape(args)}}, "# Error: File not found: #{file_path}")
          end
        when "shell"
          cmd_output = ShellCommandExecutor.execute_command(args, @config)
          text = text.gsub(%r{//shell #{Regexp.escape(args)}}, cmd_output)
        when "ruby"
          result = eval(args)
          text = text.gsub(%r{//ruby #{Regexp.escape(args)}}, result.to_s)
        when "next"
          @config.next = args.strip
        when "pipeline"
          @config.pipeline = args.strip.split(',')
        end
      end

      text
    end

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
