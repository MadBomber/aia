# lib/aia/main.rb

module AIA ; end

require_relative 'configuration'

require_relative 'cli'
require_relative 'prompt_processing'
require_relative 'external'
require_relative 'logging'

# Everything is being handled within the context
# of a single class.

class AIA::Main
  include AIA::Configuration
  include AIA::Cli
  include AIA::PromptProcessing
  include AIA::External
  include AIA::Logging


  def initialize(args= ARGV)
    setup_configuration
    setup_cli_options(args)
    setup_external_programs
  end


  def call
    show_usage    if help?
    show_version  if version?

    get_prompt
    process_prompt
    send_prompt_to_external_command
    log_result unless log.nil?
  end
end
