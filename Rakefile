# frozen_string_literal: true

 begin
   require "tocer/rake/register"
   begin
     Tocer::Rake::Register.call
   rescue => e
     warn "Skipping Tocer::Rake::Register: #{e.message}"
   end
 rescue LoadError => error
   warn error.message
 end

 begin
   require 'kramdown/man/task'
   begin
     Kramdown::Man::Task.new
   rescue => e
     warn "Skipping Kramdown man task: #{e.message}"
   end
 rescue LoadError => error
   warn error.message
 end

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.libs        << "test"
  t.libs        << "lib"
  t.warning     = false
  t.test_globs  = ["test/aia/*_test.rb", "test/aia_test.rb", "!test/integration/**/*_test.rb"]
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
