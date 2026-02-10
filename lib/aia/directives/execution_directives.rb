# lib/aia/directives/execution_directives.rb

require 'shellwords'

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

    desc "Use text-to-speech to speak the text"
    def say(args, context_manager = nil)
      system('say', *args)
      ""
    end
  end
end
