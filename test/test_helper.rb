# frozen_string_literal: true

require 'debug_me'
include DebugMe

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  formatter SimpleCov::Formatter::SimpleFormatter
end

ENV['AIA_PROMPTS_DIR'] = __dir__ + '/aia/prompts_dir'

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "aia"

require "minitest/autorun"
require "minitest/mock"
require 'mocha/minitest'
require 'minitest/pride'
require 'minitest/reporters'

# Configure test execution order and reporters
class Minitest::Test
  # Make test output more readable
  make_my_diffs_pretty!
  
  # Explicitly state that tests are order-dependent
  i_suck_and_my_tests_are_order_dependent!
end

# Configure reporters
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]

# Setup default test environment
def setup_test_environment
  AIA::Cli.new("test") unless defined?(AIA.config) && AIA.config&.arguments&.any?
end

setup_test_environment
