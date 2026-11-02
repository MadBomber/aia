# frozen_string_literal: true

source "https://rubygems.org"

# gem 'ractor_queue  # dependency of robot_lab

group :development do
  gem 'aigcm'
  gem 'debug_me'
  gem 'deep-cover', require: false
  gem 'fasterer'
  gem 'flay'
  gem 'flog'
  gem 'reek'
  gem 'rubocop'
  gem 'simplecov_lcov_formatter'

  # Not an aia dependency: users bring it with --require shared_tools.
  # Listed here so bin/aia (which runs under bundler/setup) can load it
  # and its dependencies (csv, nokogiri) for examples 18 and 30.
  gem 'dentaku' # shared_tools CalculatorTool (an optional shared_tools dependency)
  gem 'shared_tools', '>= 0.7.1'
end

gemspec
