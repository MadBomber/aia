# test/simplecov_helper.rb
#
# SimpleCov MUST be started BEFORE minitest/autorun registers its at_exit.
# Ruby's at_exit handlers run in LIFO order. If minitest/autorun is loaded
# first, its at_exit (which runs tests) fires AFTER SimpleCov's at_exit
# (which collects coverage), meaning coverage is stopped before tests run.
#
# This file is loaded via Rakefile's test_prelude to ensure correct ordering.

return if defined?(SimpleCov) && SimpleCov.running

require "simplecov"
require "simplecov_lcov_formatter"

SimpleCov.start do
  add_filter "/test/"

  # Enable branch coverage for better tracking of conditionals
  enable_coverage :branch if SimpleCov.respond_to?(:enable_coverage)

  # Enable more detailed coverage tracking
  track_files "lib/**/*.rb"

  # Custom coverage thresholds
  minimum_coverage 0
  minimum_coverage_by_file 0

  # Configure multiple formatters with more detailed output
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]

  # Add coverage groups for better organization
  add_group "Core", "lib/aia"
  add_group "Extensions", "lib/extensions"
  add_group "Refinements", "lib/refinements"
end

SimpleCov.at_exit do
  SimpleCov.result.format!

  puts "\n" + "="*50
  puts "SIMPLECOV DETAILED COVERAGE REPORT"
  puts "="*50
  puts "Overall Coverage: #{SimpleCov.result.covered_percent.round(2)}%"
  puts "Covered Lines: #{SimpleCov.result.covered_lines}/#{SimpleCov.result.total_lines}"

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

  puts "\n HIGH COVERAGE (>=80%):"
  high_coverage.each do |file|
    puts "  #{file[:name]}: #{file[:percent]}% (#{file[:covered]}/#{file[:total]} lines)"
  end

  puts "\n MEDIUM COVERAGE (40-79%):"
  medium_coverage.each do |file|
    puts "  #{file[:name]}: #{file[:percent]}% (#{file[:covered]}/#{file[:total]} lines)"
  end

  puts "\n LOW COVERAGE (<40%):"
  low_coverage.each do |file|
    puts "  #{file[:name]}: #{file[:percent]}% (#{file[:covered]}/#{file[:total]} lines)"
  end

  puts "\n SUMMARY:"
  puts "  High Coverage Files: #{high_coverage.size}"
  puts "  Medium Coverage Files: #{medium_coverage.size}"
  puts "  Low Coverage Files: #{low_coverage.size}"
  puts "="*50
end
