# frozen_string_literal: true

require 'debug_me'
include DebugMe

require 'simplecov'

SimpleCov.start 

ENV['AIA_PROMTS_DIR'] = __dir__ + '/aia/prompts_dir'

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "aia"

require "minitest/autorun"
require "minitest/mock"
require 'mocha/minitest'

# Setup default test environment
def setup_test_environment
  AIA::Cli.new("test") unless defined?(AIA.config) && AIA.config&.arguments&.any?
end

setup_test_environment
