# test/test_helper.rb

require 'debug_me'
include DebugMe

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# require "../lib/aia.rb"

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "simplecov"
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

require 'simplecov_lcov_formatter'

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

# Enhanced SimpleCov configuration for better tracking
SimpleCov.start do
  add_filter "/test/**/*_test.rb"
  
  # Enable branch coverage for better tracking of conditionals
  enable_coverage :branch if SimpleCov.respond_to?(:enable_coverage)
  
  # Enable more detailed coverage tracking
  track_files "lib/**/*.rb"
  
  # Custom coverage thresholds
  minimum_coverage 30
  minimum_coverage_by_file 25
  
  # Configure multiple formatters with more detailed output
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
  
  # Add coverage groups for better organization
  add_group "Core", "lib/aia"
  add_group "Extensions", "lib/extensions"
  add_group "Refinements", "lib/refinements"
  
  # Custom result processing to highlight specific issues
  at_exit do
    SimpleCov.result.format!
    
    # Report on files with low coverage
    puts "\n" + "="*50
    puts "SIMPLECOV DETAILED COVERAGE REPORT"
    puts "="*50
    puts "Overall Coverage: #{SimpleCov.result.covered_percent.round(2)}%"
    puts "Covered Lines: #{SimpleCov.result.covered_lines}/#{SimpleCov.result.total_lines}"
    
    # Group results by coverage level
    high_coverage = []
    medium_coverage = []
    low_coverage = []
    
    SimpleCov.result.files.each do |file|
      coverage_percent = file.covered_percent
      file_info = {
        name: file.filename.gsub(SimpleCov.root + '/', ''),
        percent: coverage_percent.round(2),
        covered: file.covered_lines.size,
        total: file.lines_of_code
      }
      
      if coverage_percent >= 80
        high_coverage << file_info
      elsif coverage_percent >= 40
        medium_coverage << file_info
      else
        low_coverage << file_info
      end
    end
    
    puts "\n🟢 HIGH COVERAGE (>=80%):"
    high_coverage.each do |file|
      puts "  #{file[:name]}: #{file[:percent]}% (#{file[:covered]}/#{file[:total]} lines)"
    end
    
    puts "\n🟡 MEDIUM COVERAGE (40-79%):"
    medium_coverage.each do |file|
      puts "  #{file[:name]}: #{file[:percent]}% (#{file[:covered]}/#{file[:total]} lines)"
    end
    
    puts "\n🔴 LOW COVERAGE (<40%):"
    low_coverage.each do |file|
      puts "  #{file[:name]}: #{file[:percent]}% (#{file[:covered]}/#{file[:total]} lines)"
      
      # Show uncovered lines for problematic files
      source_file = SimpleCov.result.files.find { |f| f.filename.include?(file[:name]) }
      if source_file
        uncovered_lines = source_file.lines.map.with_index(1) do |line, line_num|
          line_num if line.coverage == 0
        end.compact
        
        if uncovered_lines.any?
          puts "    Uncovered lines: #{uncovered_lines.first(10).join(', ')}#{uncovered_lines.size > 10 ? ' ...' : ''}"
        end
      end
    end
    
    puts "\n📊 SUMMARY:"
    puts "  High Coverage Files: #{high_coverage.size}"
    puts "  Medium Coverage Files: #{medium_coverage.size}"
    puts "  Low Coverage Files: #{low_coverage.size}"
    puts "  Target: Get all files above 40% coverage"
    
    if low_coverage.any?
      puts "\n💡 RECOMMENDATIONS:"
      low_coverage.first(3).each do |file|
        puts "  - Focus on #{file[:name]} (#{file[:percent]}% coverage)"
      end
    end
    
    puts "="*50
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
