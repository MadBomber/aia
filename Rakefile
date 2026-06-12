# frozen_string_literal: true

begin
  require "tocer/rake/register"
  Tocer::Rake::Register.call
rescue LoadError, StandardError => e
  warn "Skipping tocer tasks: #{e.message}"
end

begin
  require 'kramdown/man/task'
  Kramdown::Man::Task.new
rescue LoadError, StandardError => e
  warn "Skipping kramdown man task: #{e.message}"
end

begin
  require "bundler/gem_tasks"
rescue LoadError, StandardError => e
  warn "Skipping bundler/gem_tasks: #{e.message}"
end
require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.libs        << "test"
  t.libs        << "lib"
  t.warning = false
  # Load SimpleCov before minitest/autorun so at_exit ordering is correct
  t.test_prelude = 'ENV["TEST_SUITE"]="unit"; require "simplecov_helper"'
  # Include all unit tests under test/, excluding integration tests
  # Dir.glob does not support ! negation, so compute the file list manually
  t.test_globs = Dir["test/**/*_test.rb"].reject { |f| f.start_with?("test/integration/") }
end

Minitest::TestTask.create(:integration) do |t|
  t.libs        << "test"
  t.libs        << "lib"
  t.warning = false
  # Load SimpleCov before minitest/autorun so at_exit ordering is correct
  t.test_prelude = 'ENV["TEST_SUITE"]="integration"; require "simplecov_helper"'
  t.test_globs = ["test/integration/**/*_test.rb"]
end

desc "Run all tests including integration tests"
task all_tests: %i[test integration]

desc "Check code complexity with Flog (warn >=20, fail >=50)"
task :flog_check do
  require 'flog'

  METHOD_WARN = 20.0
  METHOD_FAIL = 50.0

  flogger = Flog.new(all: true)
  flogger.flog(*Dir.glob('lib/**/*.rb'))

  warnings = []
  failures = []

  flogger.each_by_score do |method, score|
    next if method.end_with?('#none')
    if score > METHOD_FAIL
      failures << "#{'%.1f' % score}: #{method}"
    elsif score > METHOD_WARN
      warnings << "#{'%.1f' % score}: #{method}"
    end
  end

  unless warnings.empty?
    puts "\nFlog warnings (#{METHOD_WARN}–#{METHOD_FAIL}) — target for future refactoring:"
    warnings.each { |v| puts "  #{v}" }
  end

  if failures.empty?
    puts "\nFlog: no methods exceed the failure threshold (>=#{METHOD_FAIL})"
  else
    puts "\nFlog failures (>=#{METHOD_FAIL}) — must be refactored:"
    failures.each { |v| puts "  #{v}" }
    abort "\nFlog quality gate failed: #{failures.size} method(s) exceed #{METHOD_FAIL}"
  end
end

desc "Check for structural code duplication with Flay (mass >= 50)"
task :flay_check do
  require 'flay'

  mass_threshold = 50

  flay = Flay.new({ mass: mass_threshold, diff: false, verbose: false, summary: false, timeout: 60 })
  flay.process(*Dir.glob('lib/**/*.rb'))
  flay.analyze

  if flay.hashes.empty?
    puts "\nFlay: no structural duplication detected (mass >= #{mass_threshold})"
  else
    puts "\nFlay found structural duplication (mass >= #{mass_threshold}):"
    flay.report
    abort "\nFlay quality gate failed: #{flay.hashes.length} pattern(s) detected"
  end
end

task default: :test
