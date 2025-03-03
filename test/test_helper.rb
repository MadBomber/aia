# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Load the real gems
require "prompt_manager"
require "ai_client"
require "aia"

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "simplecov"

SimpleCov.start do
  add_filter "/test/"
end

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
