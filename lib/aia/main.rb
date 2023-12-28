# lib/aia/main.rb

module AIA ; end

require_relative 'config'
require_relative 'cli'
require_relative 'prompt_processing'
require_relative 'logging'
require_relative 'tools'

# Everything is being handled within the context
# of a single class.

class AIA::Main
  include AIA::PromptProcessing

  attr_accessor :logger, :tools

  def initialize(args= ARGV)
    AIA::Cli.new(args)

    @logger = AIA::Logging.new(AIA.config.log_file)
    AIA::Tools.load_tools

    # TODO: still should verify that the tools are ion the $PATH
    # tools.class.verify_tools
  end


  def call
    get_prompt
    process_prompt
    
    # send_prompt_to_external_command

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

    backend = backend_klass.new(
                text:           @prompt.to_s,
                files:          AIA.config.arguments    # FIXME: want validated context files
              )

    result  = backend.run

    AIA.config.output_file.write result

    logger.prompt_result(@prompt, result)
  end
end
