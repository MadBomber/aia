# lib/aia/main.rb

module AIA ; end

require_relative 'config'
require_relative 'cli'
require_relative 'directives'
require_relative 'prompt'
require_relative 'logging'
require_relative 'tools'

# Everything is being handled within the context
# of a single class.

class AIA::Main

  attr_accessor :logger, :tools, :backend

  def initialize(args= ARGV)    
    AIA::Tools.load_tools

    AIA::Cli.new(args)

    AIA.config.tools = {}
    

    if AIA.config.debug?
      debug_me('== CONFIG AFTER CLI =='){[
        "AIA.config"
      ]}
    end

    @logger = AIA::Logging.new(AIA.config.log_file)

    @logger.info(AIA.config) if AIA.config.debug? || AIA.config.verbose?

    @prompt = AIA::Prompt.new.prompt

    @engine = AIA::Directives.new(prompt: @prompt)

    # TODO: still should verify that the tools are ion the $PATH
    # tools.class.verify_tools
  end




  def call
    @engine.execute_my_directives


    # TODO: the context_files left in the @arguments array
    #       should be verified BEFORE asking the user for a
    #       prompt keyword or process the prompt.  Do not
    #       want invalid files to make it this far.

    found = AIA::Tools
              .search_for(
                name: AIA.config.backend, 
                role: :backend
              )

    if found.empty?
      abort "There are no :backend tools named #{AIA.config.backend}"
    end

    if found.size > 1
      abort "There are #{found.size} :backend tools with the name #{AIAA.config.backend}"
    end

    backend_klass = found.first.klass

    abort "backend not found: #{AIA.config.backend}" if backend_klass.nil?

    the_prompt = @prompt.to_s
    
    the_prompt.prepend AIA::Clause::Terse if AIA.config.terse?

    @backend  = backend_klass.new(
                  text:           the_prompt,
                  files:          AIA.config.arguments    # FIXME: want validated context files
                )


    result  = backend.run

    AIA.config.out_file.write result

    logger.prompt_result(@prompt, result)
  end
end
