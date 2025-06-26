# test/test_helper.rb

require 'debug_me'
include DebugMe

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# require "../lib/aia.rb"

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "simplecov"

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

SimpleCov.start do
  add_filter "/test/**/*_test.rb"
  
  # Configure multiple formatters: HTML (for viewing) and LCOV (for CI/tools)
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
end
