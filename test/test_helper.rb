# test/test_helper.rb

require 'debug_me'
include DebugMe

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# require "aia"

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "simplecov"

# Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# SimpleCov.start do
#   add_filter "/test/**/*_test.rb"
# end
