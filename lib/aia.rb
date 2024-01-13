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
require 'pathname'
require 'reline'
require 'shellwords'
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
      args = args.split(' ') if args.is_a?(String)

      # TODO: Currently this is a one and done architecture.
      #       If the args contain an "-i" or and "--interactive"
      #       flag could this turn into some kind of
      #       conversation REPL?
      
      AIA::Main.new(args).call
    end
  end
end

