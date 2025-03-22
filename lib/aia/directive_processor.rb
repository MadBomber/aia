# lib/aia/directive_processor.rb
#
# This file contains the DirectiveProcessor class for handling chat-based directives.

require 'shellwords'

module AIA
  # The DirectiveProcessor class is responsible for processing directives
  # entered in the chat interface. It handles parsing, validation, and execution
  # of various directive types like shell commands, Ruby code, configuration
  # management, file inclusion, and context control.
  class DirectiveProcessor
    DIRECTIVE_PREFIX = '//'

    # Initializes a new DirectiveProcessor with the given configuration.
    #
    # @param config [OpenStruct] the configuration object
    def initialize(config)
      @config = config
    end

    # Checks if the given text is a specific type of directive.
    #
    # @param text [String] the text to check
    # @param type [String] the type of directive to check for (e.g., 'config', 'help', 'clear')
    # @return [Boolean] true if the text is the specified type of directive, false otherwise
    def directive?(text, type = nil)
      return text.strip.start_with?(DIRECTIVE_PREFIX) unless type
      text.strip.start_with?(DIRECTIVE_PREFIX + type)
    end

    # Checks if the given text is a config directive.
    #
    # @param text [String] the text to check
    # @return [Boolean] true if the text is a config directive, false otherwise
    def config_directive?(text)
      directive?(text, 'config') || directive?(text, 'cfg')
    end

    # Checks if the given text is a help directive.
    #
    # @param text [String] the text to check
    # @return [Boolean] true if the text is a help directive, false otherwise
    def help_directive?(text)
      directive?(text, 'help')
    end

    # Checks if the given text is a clear directive.
    #
    # @param text [String] the text to check
    # @return [Boolean] true if the text is a clear directive, false otherwise
    def clear_directive?(text)
      directive?(text, 'clear')
    end

    # Checks if the directive output should be excluded from the chat context.
    #
    # @param text [String] the directive text to check
    # @return [Boolean] true if the directive should be excluded, false otherwise
    def exclude_from_chat_context?(text)
      config_directive?(text) || help_directive?(text) || clear_directive?(text)
    end

    # Processes a directive and returns the result.
    #
    # @param directive_text [String] the directive text to process
    # @param history [Array] the conversation history that may be modified by directives
    # @return [Hash] A hash containing :result (String) and :modified_history (Array, only if history was modified)
    def process(directive_text, history = nil)
      result = { result: nil }

      if help_directive?(directive_text)
        result[:result] = show_help
      elsif clear_directive?(directive_text) && history
        # Create a new array rather than just clearing the existing one
        result[:modified_history] = []
        result[:result] = "Conversation context has been cleared. The AI will have no memory of our previous conversation."
      else
        # Process other directives
        directive_type, directive_args = parse_directive(directive_text)
        result[:result] = execute_directive(directive_type, directive_args)
      end

      result
    end

    # Parses the directive text to extract the directive type and arguments.
    #
    # @param directive_text [String] the directive text to parse
    # @return [Array<String>] an array containing the directive type and arguments
    def parse_directive(directive_text)
      if directive_text.start_with?('//') # //directive style
        parts = directive_text[2..-1].strip.split(' ', 2)
        directive_type = parts[0]
        directive_args = parts[1] || ''
      else # #!directive: style
        match = directive_text.match(/^\s*\#\!\s*([a-z]+)\s*\:(.*)$/i)
        directive_type = match[1].strip if match
        directive_args = match[2].strip if match
      end

      [directive_type, directive_args]
    end

    # Executes the directive based on its type and arguments.
    #
    # @param directive_type [String] the type of directive to execute
    # @param directive_args [String] the arguments for the directive
    # @return [String] the result of executing the directive
    def execute_directive(directive_type, directive_args)
      case directive_type
      when "shell", "sh"
        execute_shell_directive(directive_args)
      when "ruby", "rb"
        execute_ruby_directive(directive_args)
      when "config", "cfg"
        execute_config_directive(directive_args)
      when "include", "inc"
        execute_include_directive(directive_args)
      else
        "Unknown directive: #{directive_type}"
      end
    end

    # Executes a shell command directive.
    #
    # @param args [String] the command to execute
    # @return [String] the output of the command
    def execute_shell_directive(args)
      return "No command specified" if args.nil? || args.strip.empty?
      `#{args}`.chomp
    rescue => e
      "Error executing shell command: #{e.message}"
    end

    # Executes a Ruby code directive.
    #
    # @param args [String] the Ruby code to execute
    # @return [String] the result of executing the code
    def execute_ruby_directive(args)
      return "No Ruby code specified" if args.nil? || args.strip.empty?
      
      # Create a binding for code execution
      b = binding
      
      # Require specified libraries if configured
      if @config.respond_to?(:require_libs) && @config.require_libs.is_a?(Array) && !@config.require_libs.empty?
        @config.require_libs.each do |lib|
          begin
            b.eval("require '#{lib}'")
          rescue LoadError => e
            return "Error requiring library '#{lib}': #{e.message}"
          end
        end
      end
      
      # Execute the code in the binding with access to the required libraries
      result = b.eval(args).to_s
      result
    rescue => e
      "Error executing Ruby code: #{e.message}"
    end

    # Executes a configuration directive.
    #
    # @param args [String] the configuration command
    # @return [String] the result of the configuration operation
    def execute_config_directive(args)
      if args.nil? || args.strip.empty?
        # Show all configuration
        ap @config.to_h
        ""
      elsif args.include?('=')
        # Update configuration
        key, value = args.split('=', 2).map(&:strip)
        @config[key.to_sym] = parse_config_value(value)
        "Configuration updated: #{key} = #{@config[key.to_sym]}"
      else
        # Show specific configuration value
        key = args.strip
        "#{key} = #{@config[key.to_sym]}"
      end
    end

    # Executes a file inclusion directive.
    #
    # @param args [String] the path to the file to include
    # @return [String] the content of the file or an error message
    def execute_include_directive(args)
      return "No file path specified" if args.nil? || args.strip.empty?
      file_path = args.strip
      
      if File.exist?(file_path)
        File.read(file_path)
      else
        "Error: File not found: #{file_path}"
      end
    end

    # Parses a configuration value from a string into the appropriate type.
    #
    # @param value [String] the value to parse
    # @return [Object] the parsed value
    def parse_config_value(value)
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

    # Returns the help text for all available directives.
    #
    # @return [String] the help text
    def show_help
      <<~HELP
        Available Directives:
        //shell <command> or //sh <command> - Execute a shell command
        //ruby <code> or //rb <code> - Execute Ruby code
        //config or //cfg - Show current configuration
        //config key=value or //cfg key=value - Update configuration
        //include <file> or //inc <file> - Include file content
        //clear - Clear the current conversation context
        //help - Show this help message
      HELP
    end
  end
end
