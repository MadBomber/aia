# lib/aia.rb

require 'debug_me'
include DebugMe

require 'hashie'
require 'pathname'
require 'readline'
require 'tempfile'

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'

require_relative "aia/version"
require_relative "aia/main"
require_relative "core_ext/string_wrap"

module AIA
  class << self
    attr_accessor :config

    def run(args=ARGV)
      self.config = Hashie::Mash.new
      args        = args.split(' ') if args.is_a?(String)

      # TODO: Currently this is a one and done architecture.
      #       If the args contain an "-i" or and "--interactive"
      #       flag could this turn into some kind of
      #       conversation REPL?
      
      AIA::Main.new(args).call

      debug_me{[
        "AIA.config",
        "AIA.config.edit?",
        "AIA.config.debug?",
        "AIA.config.verbose?"
      ]}
    end
  end
end

