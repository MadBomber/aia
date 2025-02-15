# frozen_string_literal: true

require 'debug_me'
include DebugMe

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  formatter SimpleCov::Formatter::SimpleFormatter
end

# Test environment setup
ENV['AIA_PROMPTS_DIR'] = File.expand_path('../aia/prompts_dir', __FILE__)
ENV['AIA_LOG_FILE'] = File.expand_path('../tmp/test.log', __FILE__)
ENV['TEST_MODE'] = 'true'

# Create test directories if they don't exist
FileUtils.mkdir_p(File.dirname(ENV['AIA_LOG_FILE']))
FileUtils.mkdir_p(ENV['AIA_PROMPTS_DIR'])

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
require 'tty-spinner'
require 'fileutils'
require 'pathname'
require 'stringio'



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
      mock = Minitest::Mock.new
      mock.expect(:run, 'test')
      
      AIA::Fzf.stub(:new, mock) do
        yield
      end
    end
  end

  def setup_test_config
    @original_config = AIA.config
    AIA.config = AIA::Config.new
    AIA.config.log_file = ENV['AIA_LOG_FILE']
    AIA.config.prompts_dir = ENV['AIA_PROMPTS_DIR']
    AIA.config.arguments = ["test"]
  end

  def teardown_test_config
    AIA.config = @original_config
  end

  def with_temp_dir
    dir = Dir.mktmpdir
    yield Pathname.new(dir)
  ensure
    FileUtils.remove_entry dir if dir
  end

  def capture_subprocess_io
    orig_stdout = $stdout.dup
    orig_stderr = $stderr.dup
    captured_stdout = StringIO.new
    captured_stderr = StringIO.new
    $stdout = captured_stdout
    $stderr = captured_stderr

    yield

    [captured_stdout.string, captured_stderr.string]
  ensure
    $stdout = orig_stdout
    $stderr = orig_stderr
  end
end

# Configure test execution order and reporters
class Minitest::Test
  include TestHelpers
  
  make_my_diffs_pretty!
  i_suck_and_my_tests_are_order_dependent!

  def setup
    ENV['TEST_MODE'] = 'true'
    setup_test_config
    super
  end

  def teardown
    teardown_test_config
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
      mock = Minitest::Mock.new
      mock.expect(:run, 'test')
      
      AIA::Fzf.stub(:new, mock) do
        AIA::Cli.new("test") unless defined?(AIA.config) && AIA.config&.arguments&.any?
      end
    end
  rescue StandardError => e
    puts "Warning: Test environment setup failed: #{e.message}"
    puts "Some tests may fail if they depend on configuration"
  end
end

extend TestHelpers
setup_test_environment

# Cleanup on exit
at_exit do
  FileUtils.rm_rf(ENV['AIA_PROMPTS_DIR']) if Dir.exist?(ENV['AIA_PROMPTS_DIR'])
  FileUtils.rm_rf(File.dirname(ENV['AIA_LOG_FILE'])) if Dir.exist?(File.dirname(ENV['AIA_LOG_FILE']))
end
