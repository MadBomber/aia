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

# Add lib and test directories to load path
lib_path = File.expand_path('../lib', __dir__)
test_path = File.expand_path(__dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
$LOAD_PATH.unshift(test_path) unless $LOAD_PATH.include?(test_path)
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
  begin
    AIA::Cli.new("test") unless defined?(AIA.config) && AIA.config&.arguments&.any?
  rescue StandardError => e
    puts "Warning: Test environment setup failed: #{e.message}"
    puts "Some tests may fail if they depend on configuration"
  end
end

setup_test_environment
