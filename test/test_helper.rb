# frozen_string_literal: true

require 'debug_me'
include DebugMe

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Create test directories if they don't exist
test_prompts_dir = File.expand_path("../test/prompts", __dir__)
test_roles_dir = File.expand_path("../test/roles", __dir__)
Dir.mkdir(test_prompts_dir) unless Dir.exist?(test_prompts_dir)
Dir.mkdir(test_roles_dir) unless Dir.exist?(test_roles_dir)

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

debug_me('==========>>>>>>>>>>')

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

debug_me('<<<<<<<<<==========')
