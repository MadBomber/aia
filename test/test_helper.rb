# frozen_string_literal: true

require 'debug_me'
include DebugMe

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  formatter SimpleCov::Formatter::SimpleFormatter
end

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
require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/reporters'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'aia'

# Configure Minitest reporters
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]
