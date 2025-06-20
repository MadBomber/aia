# experiments/ai_misc/coding_agent_with_ruby_llm/tools/run_shell_command.rb

require "io/console"
require "ruby_llm/tool"

module Tools
  class RunShellCommand < RubyLLM::Tool
    description "Execute a linux shell command"
    param :command, desc: "The command to execute"

    def execute(command:)
      print "\n\n"
      puts "AI wants to execute the following shell command:"
      puts "="*command.size
      puts command
      puts "="*command.size
      print "\n\n"

      sleep 0.5
      print "Execute the command? (y/N):"
      allowed = STDIN.getch == "y"

      unless allowed
        print "Command aborted" + " "*30 if defined?(AIA)
        return { error: "User declined to execute the command" }
      end

      `#{command}`
    rescue => e
      { error: e.message }
    end
  end
end
