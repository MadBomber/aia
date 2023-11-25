# lib/aia/main.rb

module AIA
end

# This module defines constants that may
# be used by other modules.  It should come first.
require_relative 'configuration'

# The order of the following is not important
require_relative 'cli'
require_relative 'prompt_processing'
require_relative 'ai_command'
require_relative 'logging'


class AIA::RememberTheMain
  include AIA::Configuration
  include AIA::Cli
  include AIA::PromptProcessing
  include AIA::AiCommand
  include AIA::Logging

  def self.hello
    puts "Its Alive!"
  end
end

AIA::RememberTheMain.hello

