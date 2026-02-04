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
  t.warning     = false
  # Load SimpleCov before minitest/autorun so at_exit ordering is correct
  t.test_prelude = 'require "simplecov_helper"'
  # Include all unit tests under test/, excluding integration tests
  t.test_globs  = ["test/**/*_test.rb", "!test/integration/**/*_test.rb"]
end

Minitest::TestTask.create(:integration) do |t|
  t.libs        << "test"
  t.libs        << "lib"
  t.warning     = false
  t.test_globs  = ["test/integration/**/*_test.rb"]
end

desc "Run all tests including integration tests"
task all_tests: [:test, :integration]

task default: :test
