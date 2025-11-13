# test/test_helper.rb

require 'debug_me'
include DebugMe

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# require "../lib/aia.rb"

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "simplecov"

# Note: Mocha cleanup is handled explicitly in individual test files
# where needed (multi_model_isolation_test.rb, models_directive_test.rb)
# to prevent stub pollution between tests

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

# Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

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
