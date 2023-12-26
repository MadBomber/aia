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
    @tools  = AIA::Tools.new

    tools.class.verify_tools
  end


  def call
    get_prompt
    process_prompt
    
    # send_prompt_to_external_command

    # TODO: the context_files left in the @arguments array
    #       should be verified BEFORE asking the user for a
    #       prompt keyword or process the prompt.  Do not
    #       want invalid files to make it this far.


    mods    = AIA::Mods.new(
                extra_options:  AIA.config.extra,
                text:           @prompt.to_s,
                files:          AIA.config.arguments    # FIXME: want validated context files
              )

    result  = mods.run

    AIA.config.output_file.write result

    logger.prompt_result(@prompt, result)
  end
end
