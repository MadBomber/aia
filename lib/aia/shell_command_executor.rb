# lib/aia/shell_command_executor.rb
#
# This file contains the ShellCommandExecutor class for processing shell commands.
# The ShellCommandExecutor class provides a consistent way to execute shell commands
# across different parts of the AIA gem, ensuring uniform behavior for all shell
# command execution methods ($(command), //shell directive, and backticks).

module AIA
  # The ShellCommandExecutor class provides a consistent way to execute shell commands
  # across different parts of the AIA gem, ensuring uniform behavior for all shell
  # command execution methods ($(command), //shell directive, and backticks).
  class ShellCommandExecutor
    # Dangerous command patterns that could potentially cause damage
    DANGEROUS_PATTERNS = [
      # File system destructive commands
      /\brm\s+(-[a-z]*)?f/i,                 # rm with force flag
      /\bmkfs/i,                           # format filesystems
      /\bdd\b.*\bof=/i,                    # dd with output file
      /\bshred\b/i,                        # securely delete files
      # System modification commands
      /\bsystemctl\s+(stop|disable|mask)/i, # stopping system services
      /\bchmod\s+777\b/i,                  # setting dangerous permissions
      /\b(halt|poweroff|shutdown|reboot)\b/i, # system power commands
      # Network security related
      /\btcpdump\b/i,                      # packet capturing
      /\bifconfig\b.*\bdown\b/i,           # taking down network interfaces
      # Process control
      /\bkill\s+-9\b/i,                    # force killing processes
      /\bpkill\b/i                         # pattern-based process killing
    ].freeze

    # Maximum command length for safety reasons
    MAX_COMMAND_LENGTH = 500

    # Initialize a new ShellCommandExecutor with the given configuration
    #
    # @param config [OpenStruct, nil] the configuration object
    def initialize(config = nil)
      @config = config
    end

    # Class-level factory method to create an executor with config
    #
    # @param config [OpenStruct, nil] the configuration object
    # @return [ShellCommandExecutor] a new ShellCommandExecutor instance
    def self.with_config(config)
      new(config)
    end

    # Class-level method to maintain backwards compatibility
    #
    # @param command [String] the shell command to execute
    # @param config [OpenStruct, nil] the configuration object
    # @return [String] the output of the command or an error message
    def self.execute_command(command, config = nil)
      new(config).execute_command(command)
    end

    # Executes a shell command and returns its output.
    #
    # @param command [String] the shell command to execute
    # @return [String] the output of the command or an error message
    def execute_command(command)
      return "No command specified" if blank?(command)

      validation_result = validate_command(command)
      return validation_result if validation_result

      # Execute the command
      `#{command}`.chomp
    rescue StandardError => error
      "Error executing shell command: #{error.message}"
    end

    # Checks if a command is potentially dangerous
    #
    # @param command [String] the shell command to check
    # @return [Boolean] true if the command matches dangerous patterns
    def dangerous_command?(command)
      return false if blank?(command)
      DANGEROUS_PATTERNS.any? { |pattern| command =~ pattern }
    end

    private

    # Check if a string is nil or empty
    #
    # @param str [String, nil] the string to check
    # @return [Boolean] true if the string is nil or empty
    def blank?(str)
      str.nil? || str.strip.empty?
    end

    # Validate a command for safety and length constraints
    #
    # @param command [String] the command to validate
    # @return [String, nil] error message if validation fails, nil if command is valid
    def validate_command(command)
      command_length = command.length
      # Trim the command if it's too long
      if command_length > MAX_COMMAND_LENGTH
        return "Error: Command too long (#{command_length} chars). Maximum length is #{MAX_COMMAND_LENGTH}."
      end

      # Check for dangerous commands
      is_dangerous = dangerous_command?(command)

      # Block dangerous commands if configured
      if config_flag?(:strict_shell_safety) && is_dangerous
        return "Error: Potentially dangerous command blocked for security reasons: '#{command}'"
      end

      # Request confirmation for dangerous commands if configured
      if config_flag?(:shell_confirm) && is_dangerous
        return prompt_confirmation(command)
      end

      nil # Command is valid
    end

    # Check if a configuration flag is enabled
    #
    # @param flag [Symbol] the flag to check
    # @return [Boolean] true if the flag is enabled
    def config_flag?(flag)
      @config && @config.respond_to?(flag) && @config.send(flag)
    end

    # Prompt the user for confirmation to execute a dangerous command
    #
    # @param command [String] the command to confirm
    # @return [String, nil] error message if user declines, nil if user confirms
    def prompt_confirmation(command)
      puts "\n⚠️  WARNING: Potentially dangerous shell command detected:"
      puts "\n    #{command}\n"
      print "\nDo you want to execute this command? [y/N]: "
      confirm = STDIN.gets.chomp.downcase
      return "Command execution canceled by user" unless confirm == 'y'
      nil
    end
  end
end
