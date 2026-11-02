return if defined?(SimpleCov) && SimpleCov.running

require "simplecov"
require "simplecov_lcov_formatter"

SimpleCov.start do
  command_name(ENV.fetch('TEST_SUITE', 'unit'))

  add_filter "/test/"
  add_filter "/vendor/"

  enable_coverage :branch
  track_files "lib/**/*.rb"

  add_group "Core",    "lib/aia"
  add_group "Config",  "lib/aia/config"
  add_group "Directives", "lib/aia/directives"
  add_group "Tools",   "lib/aia/tools"

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
end
