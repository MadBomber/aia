# frozen_string_literal: true

require 'debug_me'
include DebugMe

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  formatter SimpleCov::Formatter::SimpleFormatter
end

ENV['AIA_PROMPTS_DIR'] = File.expand_path('../aia/prompts_dir', __FILE__)
ENV['AIA_LOG_FILE'] = File.expand_path('../tmp/test.log', __FILE__)
ENV['TEST_MODE'] = 'true'

# Create test directories if they don't exist
FileUtils.mkdir_p(File.dirname(ENV['AIA_LOG_FILE']))

# Add lib and test directories to load path
lib_path = File.expand_path('../lib', __dir__)
test_path = File.expand_path(__dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
$LOAD_PATH.unshift(test_path) unless $LOAD_PATH.include?(test_path)

# Load required libraries
require "minitest/autorun"
require "minitest/mock"
require 'mocha/minitest'
require 'minitest/pride'
require 'minitest/reporters'
require 'reline'

# Load the main library first
require "aia"

module TestHelpers
  def with_stdin
    stdin = $stdin
    $stdin, write = IO.pipe
    yield write
  ensure
    write.close
    $stdin = stdin
  end

  def simulate_user_input(input)
    Reline.stub :readline, input do
      mock = Object.new
      def mock.run; 'test'; end
      
      # Use mocha's stubbing
      AIA::Fzf.stubs(:new).returns(mock)
      yield
    end
  end
end

# Configure test execution order and reporters
class Minitest::Test
  include TestHelpers
  
  make_my_diffs_pretty!
  i_suck_and_my_tests_are_order_dependent!

  def setup
    ENV['TEST_MODE'] = 'true'
    super
  end
end

# Configure reporters with detailed output
Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(
    color: true,
    detailed_skip: true,
    fast_fail: true
  )
]

# Setup default test environment
def setup_test_environment
  begin
    Reline.stub :readline, "test_input" do
      AIA::Cli.new("test") unless defined?(AIA.config) && AIA.config&.arguments&.any?
    end
  rescue StandardError => e
    puts "Warning: Test environment setup failed: #{e.message}"
    puts "Some tests may fail if they depend on configuration"
  end
end

extend TestHelpers
setup_test_environment
