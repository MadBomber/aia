# lib/aia.rb

def tramp_require(what, &block)
  loaded, require_result = false, nil

  begin
    require_result = require what
    loaded = true
  rescue Exception => ex
    # Do nothing
  end

  yield if loaded and block_given?

  require_result
end

tramp_require('debug_me') {
  include DebugMe
}

require 'hashie'
require 'openai'
require 'os'
require 'pathname'
require 'reline'
require 'shellwords'
require 'tempfile'

require 'tty-spinner'

unless TTY::Spinner.new.respond_to?(:log)
  # Allows messages to be sent to the console while
  # the spinner is still spinning.
  require_relative './core_ext/tty-spinner_log'
end

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'

require_relative "aia/version"
require_relative "aia/clause"
require_relative "aia/main"
require_relative "core_ext/string_wrap"

module AIA
  class << self
    attr_accessor :config
    attr_accessor :client

    def run(args=ARGV)
      args = args.split(' ') if args.is_a?(String)

      # TODO: Currently this is a one and done architecture.
      #       If the args contain an "-i" or and "--interactive"
      #       flag could this turn into some kind of
      #       conversation REPL?
      
      AIA::Main.new(args).call
    end


    def speak(what)
      return unless config.speak?

      if OS.osx? && 'siri' == config.voice.downcase
        system "say #{Shellwords.escape(what)}"
      else
        Client.speak(what)
      end
    end


    def verbose?  = AIA.config.verbose?
    def debug?    = AIA.config.debug?
  end
end

