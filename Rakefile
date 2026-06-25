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

# Quality gates use a committed BASELINE so accumulated debt doesn't block every
# change: they fail only on NEW or WORSENED items, not on pre-existing ones.
# Regenerate after intentionally accepting (or clearing) debt with the
# corresponding *_baseline task. Ratchet down by re-baselining once you fix items.
QUALITY_DIR   = '.quality'
FLOG_BASELINE = File.join(QUALITY_DIR, 'flog_baseline.txt')
FLAY_BASELINE = File.join(QUALITY_DIR, 'flay_baseline.txt')
FLOG_FAIL     = 50.0
FLOG_WARN     = 20.0
FLOG_EPSILON  = 0.5 # tolerate float jitter when comparing to the baseline

# @return [Hash{String=>Float}] method => score for methods over the fail line
def flog_failures
  require 'flog'
  flogger = Flog.new(all: true)
  flogger.flog(*Dir.glob('lib/**/*.rb'))
  failures = {}
  flogger.each_by_score do |method, score|
    next if method.end_with?('#none')

    failures[method] = score if score > FLOG_FAIL
  end
  failures
end

def load_flog_baseline
  return {} unless File.exist?(FLOG_BASELINE)

  File.readlines(FLOG_BASELINE).each_with_object({}) do |line, acc|
    score, method = line.strip.split("\t", 2)
    acc[method] = score.to_f if method && !method.empty?
  end
end

# @return [Flay] processed + analyzed flay instance
def flay_patterns
  require 'flay'
  flay = Flay.new(mass: 50, diff: false, verbose: false, summary: false, timeout: 60)
  flay.process(*Dir.glob('lib/**/*.rb'))
  flay.analyze
  flay
end

def load_flay_baseline
  return [] unless File.exist?(FLAY_BASELINE)

  File.readlines(FLAY_BASELINE).map(&:strip).reject(&:empty?)
end

desc "Regenerate the flog baseline (grandfathers current methods >= #{FLOG_FAIL})"
task :flog_baseline do
  require 'fileutils'
  FileUtils.mkdir_p(QUALITY_DIR)
  failures = flog_failures
  body = failures.sort_by { |_, s| -s }.map { |m, s| format("%.1f\t%s", s, m) }.join("\n")
  File.write(FLOG_BASELINE, body.empty? ? '' : "#{body}\n")
  puts "Wrote #{failures.size} grandfathered method(s) to #{FLOG_BASELINE}"
end

desc "Check complexity with Flog (fails only on NEW or worsened methods >= #{FLOG_FAIL})"
task :flog_check do
  current  = flog_failures
  baseline = load_flog_baseline

  new_items = current.reject { |m, _| baseline.key?(m) }
  worsened  = current.select { |m, s| baseline.key?(m) && s > baseline[m] + FLOG_EPSILON }
  fixed     = baseline.keys - current.keys

  puts "\nFlog: #{current.size} method(s) >= #{FLOG_FAIL} (#{baseline.size} grandfathered)."
  puts "  #{fixed.size} now under threshold — run `rake flog_baseline` to prune." unless fixed.empty?

  problems = new_items.map { |m, s| format("NEW      %.1f: %s", s, m) } +
             worsened.map  { |m, s| format("WORSENED %.1f (baseline %.1f): %s", s, baseline[m], m) }

  if problems.empty?
    puts "Flog quality gate passed (no new or worsened methods)."
  else
    puts "\nFlog quality gate failed:"
    problems.each { |p| puts "  #{p}" }
    abort "\nFlog: #{problems.size} new/worsened method(s). Refactor them, or `rake flog_baseline` if intentional."
  end
end

desc "Regenerate the flay baseline (grandfathers current duplication patterns)"
task :flay_baseline do
  require 'fileutils'
  FileUtils.mkdir_p(QUALITY_DIR)
  hashes = flay_patterns.hashes.keys.map(&:to_s).sort
  File.write(FLAY_BASELINE, hashes.empty? ? '' : "#{hashes.join("\n")}\n")
  puts "Wrote #{hashes.size} grandfathered duplication pattern(s) to #{FLAY_BASELINE}"
end

desc "Check duplication with Flay (fails only on NEW patterns, mass >= 50)"
task :flay_check do
  flay     = flay_patterns
  baseline = load_flay_baseline
  current  = flay.hashes.keys.map(&:to_s)

  new_patterns = current - baseline
  fixed        = baseline - current

  puts "\nFlay: #{current.size} duplication pattern(s) (#{baseline.size} grandfathered)."
  puts "  #{fixed.size} baseline pattern(s) gone — run `rake flay_baseline` to prune." unless fixed.empty?

  if new_patterns.empty?
    puts "Flay quality gate passed (no new duplication)."
  else
    puts "\nFlay quality gate failed: #{new_patterns.size} NEW pattern(s) (see report):"
    flay.report
    abort "\nFlay: new duplication introduced. Remove it, or `rake flay_baseline` if intentional."
  end
end

task default: :test
