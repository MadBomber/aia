# lib/aia/directives/execution.rb

module AIA
  module Directives
    module Execution
      def self.ruby(args, context_manager = nil)
          ruby_code = args.join(' ')

          begin
            String(eval(ruby_code))
          rescue Exception => e
            <<~ERROR
              This ruby code failed: #{ruby_code}
              #{e.message}
            ERROR
          end
        end

      def self.shell(args, context_manager = nil)
        shell_code = args.join(' ').strip

        if shell_code.empty?
          puts "Usage: /shell <command>"
          return ""
        end

        `#{shell_code}`
      end

      def self.say(args, context_manager = nil)
        `say #{args.join(' ')}`
        ""
      end

      # Set up aliases - these work on the module's singleton class
      class << self
        alias_method :rb, :ruby
        alias_method :sh, :shell
      end
    end
  end
end
