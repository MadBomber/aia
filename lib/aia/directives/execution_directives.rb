# lib/aia/directives/execution_directives.rb

module AIA
  class ExecutionDirectives < Directive
    desc "Execute Ruby code"
    def ruby(args, context_manager = nil)
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
    alias_method :rb, :ruby

    desc "Execute shell commands"
    def shell(args, context_manager = nil)
      shell_code = args.join(' ').strip

      if shell_code.empty?
        puts "Usage: /shell <command>"
        return ""
      end

      `#{shell_code}`
    end
    alias_method :sh, :shell

    desc "Use text-to-speech to speak the text"
    def say(args, context_manager = nil)
      `say #{args.join(' ')}`
      ""
    end
  end
end
