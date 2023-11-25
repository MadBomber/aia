# lib/aia/main.rb


###################################################
## Temporary Stuff for manual testing
#

require 'amazing_print'
require 'pathname'
require 'readline'
require 'tempfile'


require 'debug_me'
include DebugMe

$DEBUG_ME = true # ARGV.include?("--debug") || ARGV.include?("-d")

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'

require_relative "version"
require_relative "../core_ext/string_wrap"

#
## Temporary Stuff for manual testing
###################################################

module AIA
end

# This module defines constants that may
# be used by other modules.  It should come first.
require_relative 'configuration'

# The order of the following is not important
require_relative 'cli'
require_relative 'external_commands'
require_relative 'prompt_processing'
require_relative 'logging'


class AIA::RememberTheMain
  include AIA::Configuration
  include AIA::Cli
  include AIA::PromptProcessing
  include AIA::ExternalCommands
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


# TODO: gotta do some here after moving day
# Create an instance of the RememberTheMain class and run the program
AIA::RememberTheMain.new.call if $PROGRAM_NAME == __FILE__


__END__


# TODO: Consider using this history process to preload the default
#       so that an up arrow will bring the previous answer into
#       the read buffer for line editing.
#       Instead of usin the .history file just push the default
#       value from the JSON file.

while input = Readline.readline('> ', true)
  # Skip empty entries and duplicates
  if input.empty? || Readline::HISTORY.to_a[-2] == input
    Readline::HISTORY.pop
  end
  break if input == 'exit'

  # Do something with the input
  puts "You entered: #{input}"

  # Save the history in case you want to preserve it for the next sessions
  File.open('.history', 'a') { |f| f.puts(input) }
end

# Load history from file at the beginning of the program
if File.exist?('.history')
  File.readlines('.history').each do |line|
    Readline::HISTORY.push(line.chomp)
  end
end

