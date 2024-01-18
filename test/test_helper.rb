# frozen_string_literal: true

require 'debug_me'
include DebugMe

require 'simplecov'

SimpleCov.start 


$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "aia"

require "minitest/autorun"
require "minitest/mock"
require 'mocha/minitest'

