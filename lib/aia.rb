# lib/aia.rb

require 'debug_me'
include DebugMe


require 'pathname'
require 'readline'
require 'tempfile'

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'

require_relative "aia/version"
require_relative "aia/main"
require_relative "core_ext/string_wrap"

module AIA
  def self.run(args=ARGV)
    args = args.split(' ') if args.is_a?(String)
    AIA::Main.new(args).call
  end
end

