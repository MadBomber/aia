# lib/aia/main.rb

module AIA ; end

require_relative 'configuration'

require_relative 'cli'
require_relative 'prompt_processing'
require_relative 'logging'
require_relative 'tools'

# Everything is being handled within the context
# of a single class.

class AIA::Main
  include AIA::Configuration
  include AIA::Cli
  include AIA::PromptProcessing


  attr_accessor :logger, :tools

  def initialize(args= ARGV)
    setup_configuration
    setup_cli_options(args)
    # setup_external_programs
    @logger = AIA::Logging.new(log)
    @tools  = AIA::Tools.new

    tools.class.verify_tools
  end


  def call
    show_usage    if help?
    show_version  if version?

    get_prompt
    process_prompt
    # send_prompt_to_external_command

    # TODO: the context_files left in the @arguments array
    #       should be verified BEFORE asking the user for a
    #       prompt keyword or process the prompt.  Do not
    #       want invalid files to make it this far.


    mods    = AIA::Mods.new(
                extra_options:  @extra_options,
                text:           @prompt.to_s,
                files:          @arguments    # FIXME: want validated context files
              )

    result  = mods.run

    @options[:output].first.write result


    logger.prompt_result(@prompt, result)
  end
end
