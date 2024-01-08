# lib/aia/chow_main.rb

require_relative 'config'
require_relative 'chat'
require_relative 'cli'
require_relative 'directives'
require_relative 'prompt'
require_relative 'logging'
require_relative 'tools'

module AIA
  class ChowMain

    attr_accessor :logger, :tools, :backend

    def initialize(args = ARGV)
      AIA::Cli.new(args)
      AIA::Tools.load_tools
      
      AIA.config.tools = {}

      @prompt   = AIA::Prompt.new.prompt

      @logger   = AIA::Logging.new(AIA.config.log_file)
      @engine   = AIA::Directives.new(prompt: @prompt)
      @backend  = AIA::Tools.setup_backend
    end

    def call
      if AIA.config.chat?
        run_chat
      else
        execute_directives

        result = run_backend

        write_output(result)
        log_result(result)
      end
    end

    private

    def run_chat
      AIA::Chat.new(
        prompt:   @prompt
      ).run 
    end


    def execute_directives
      @engine.execute_my_directives
    end


    def run_backend
      debug_me{[ "@prompt"]}
      the_prompt = @prompt.to_s
      the_prompt.prepend AIA::Clause::Terse if AIA.config.terse?

      debug_me{[ :the_prompt ]}

      backend.text  = the_prompt
      backend.files = AIA.config.arguments

      debug_me{[
        "backend"
      ]}

      backend.run
    end


    def validated_files
      # Assume we have a process to validate files here, replace this method body with the validation logic
      AIA.config.arguments
    end

    def write_output(result)
      File.write(AIA.config.out_file, result)
    end

    def log_result(result)
      @logger.prompt_result(@prompt, result)
    end
  end
end

