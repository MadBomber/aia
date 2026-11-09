return if defined?(SimpleCov) && SimpleCov.running

require "simplecov"
require "simplecov_lcov_formatter"

SimpleCov.start do
  command_name(ENV.fetch('TEST_SUITE', 'unit'))

  skip "/test/"
  skip "/vendor/"

  enable_coverage :branch
  # `cover` restricts the report to the matching globs, so name bin/migrate_prompts
  # explicitly to keep it in the report alongside lib/**/*.rb (the set the former
  # `track_files "lib/**/*.rb"` produced once bin/migrate_prompts was loaded).
  cover "lib/**/*.rb", "bin/migrate_prompts"

  group "Core",    "lib/aia"
  group "Config",  "lib/aia/config"
  group "Directives", "lib/aia/directives"
  group "Tools",   "lib/aia/tools"

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
end
