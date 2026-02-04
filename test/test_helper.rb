# test/test_helper.rb

# Load SimpleCov first - must be before minitest/autorun for correct
# at_exit ordering. When run via Rake, this is already loaded via
# test_prelude; require is idempotent so this is safe either way.
require_relative "simplecov_helper"

require 'debug_me'
include DebugMe

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "lumberjack"

# Note: Mocha cleanup is handled explicitly in individual test files
# where needed (multi_model_isolation_test.rb, models_directive_test.rb)
# to prevent stub pollution between tests

# =============================================================================
# Lumberjack Test Mode Configuration
# =============================================================================
# Enable Lumberjack's :test device for capturing log entries in memory.
# This allows tests to make assertions about logging behavior.
#
# Usage in tests:
#   entries = AIA::LoggerManager.test_entries(:aia)
#   assert entries.any? { |e| e.message.include?("expected message") }
#
#   last = AIA::LoggerManager.last_test_entry(:aia)
#   assert_equal "Expected message", last.message
#
# The test mode is enabled after AIA is loaded (see below)

# Override Kernel#exit to prevent tests from terminating prematurely
module Kernel
  alias_method :original_exit, :exit
  def exit(status=true)
    if defined?(Minitest) && Minitest.class_variable_defined?(:@@installed_at_exit)
      warn "Exit called with status #{status} - ignoring to allow tests to continue"
      # Return a truthy value to simulate successful exit
      return status == 0 || status == true
    else
      original_exit(status)
    end
  end

  alias_method :original_exit!, :exit!
  def exit!(status=false)
    if defined?(Minitest) && Minitest.class_variable_defined?(:@@installed_at_exit)
      warn "Exit! called with status #{status} - ignoring to allow tests to continue"
      # Return a falsey value to simulate unsuccessful exit
      return status == 0 || status == true
    else
      original_exit!(status)
    end
  end
end

# =============================================================================
# Skip Tracker Plugin for Minitest
# =============================================================================
# Tracks all skipped tests and displays them at the end of the test run
# with their skip reasons.

$skipped_tests = []

module Minitest
  class SkipTracker < AbstractReporter
    def record(result)
      return unless result.skipped?

      $skipped_tests << {
        klass: result.klass,
        name: result.name,
        location: result.source_location,
        reason: result.failure&.message || 'No reason given'
      }
    end

    def report
      return if $skipped_tests.empty?

      puts "\n" + "="*70
      puts "SKIPPED TESTS (#{$skipped_tests.size})"
      puts "="*70

      $skipped_tests.each_with_index do |skip, index|
        puts "\n#{index + 1}. #{skip[:klass]}##{skip[:name]}"
        if skip[:location]
          file, line = skip[:location]
          puts "   Location: #{file}:#{line}"
        end
        puts "   Reason: #{skip[:reason]}"
      end

      puts "\n" + "="*70
    end
  end
end

# Register the skip tracker as an additional reporter
Minitest.extensions << 'skip_tracker'

module Minitest
  def self.plugin_skip_tracker_init(options)
    reporter << SkipTracker.new
  end
end

# =============================================================================
# Load AIA and Enable Test Mode Logging
# =============================================================================
# Require AIA after SimpleCov is configured so coverage is tracked.
# Then enable Lumberjack's :test device for all loggers.

require "aia"

# Enable test mode for all AIA loggers - captures entries in memory
AIA::LoggerManager.test_mode!(level: :debug)

# =============================================================================
# Minitest Plugin for Lumberjack Log Cleanup
# =============================================================================
# Clear log entries between tests to prevent pollution.
# This ensures each test starts with a clean log state.

module Minitest
  class Test
    # Hook that runs before each test method
    def before_setup
      super
      # Clear all test log entries before each test
      AIA::LoggerManager.clear_test_logs! if AIA::LoggerManager.test_mode?
    end
  end
end
