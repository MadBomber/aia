# lib/aia/shell_command_executor.rb

module AIA
  class ShellCommandExecutor
    DANGEROUS_PATTERNS = [
      # File system destructive commands
      /\brm\s+(-[a-z]*)?f/i,               # rm with force flag
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


    MAX_COMMAND_LENGTH = 500



    def initialize
      # Stub method for future implementation
    end

    # Class-level





    def self.execute_command(command)
      new.execute_command(command)
    end



    def execute_command(command)
      return "No command specified" if blank?(command)

      validation_result = validate_command(command)
      return validation_result if validation_result

      `#{command}`.chomp
    rescue StandardError => error
      "Error executing shell command: #{error.message}"
    end



    def dangerous_command?(command)
      return false if blank?(command)
      DANGEROUS_PATTERNS.any? { |pattern| command =~ pattern }
    end

    private



    def blank?(str)
      str.nil? || str.strip.empty?
    end



    def validate_command(command)
      command_length = command.length

      if command_length > MAX_COMMAND_LENGTH
        return "Error: Command too long (#{command_length} chars). Maximum length is #{MAX_COMMAND_LENGTH}."
      end


      is_dangerous = dangerous_command?(command)


      if AIA.strict_shell_safety? && is_dangerous
        return "Error: Potentially dangerous command blocked for security reasons: '#{command}'"
      end

      if AIA.shell_confirm? && is_dangerous
        return prompt_confirmation(command)
      end

      nil # Command is valid
    end







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
