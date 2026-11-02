# frozen_string_literal: true

# SimpleCov is started by the Rakefile prelude (require "simplecov_helper")
# before minitest/autorun registers its at_exit. This require is a no-op
# when loaded that way; it only takes effect when running a single test file
# directly (e.g. ruby -Ilib:test test/foo_test.rb).
require_relative "simplecov_helper"

require "fileutils"
require "debug_me"
include DebugMe

TEST_TMPDIR = File.expand_path("tmp", __dir__) unless defined?(TEST_TMPDIR)
FileUtils.mkdir_p(TEST_TMPDIR)
ENV["TMPDIR"] = TEST_TMPDIR
ENV["TMP"]    = TEST_TMPDIR
ENV["TEMP"]   = TEST_TMPDIR

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "lumberjack"

# rubocop:disable Style/FileOpen, Style/GlobalStdStream, Layout/LineLength
$stdout = File.open("test_output.txt", "w").tap { |f| f.sync = true }

class TerminalSummaryReporter < Minitest::Reporters::BaseReporter
  def report
    super
    ok    = failures.zero? && errors.zero?
    badge = ok ? "\e[32mPASS\e[0m" : "\e[31mFAIL\e[0m"
    STDOUT.puts "[#{badge}] #{count} tests, #{failures} failures, #{errors} errors, #{skips} skips (#{format('%.2f', total_time)}s) — see test_output.txt"
    STDOUT.flush
  end
end
# rubocop:enable Style/FileOpen, Style/GlobalStdStream, Layout/LineLength

Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(color: false, slow_count: 5),
  TerminalSummaryReporter.new
]

# Prevent AIA's exit/abort calls from terminating the test process mid-run.
module Kernel
  alias original_exit exit
  def exit(status = true)
    if defined?(Minitest) && Minitest.class_variable_defined?(:@@installed_at_exit)
      warn "exit(#{status}) suppressed during test run"
      [0, true].include?(status)
    else
      original_exit(status)
    end
  end

  alias original_exit! exit!
  def exit!(status = false)
    if defined?(Minitest) && Minitest.class_variable_defined?(:@@installed_at_exit)
      warn "exit!(#{status}) suppressed during test run"
      [0, true].include?(status)
    else
      original_exit!(status)
    end
  end
end

require "aia"

AIA::LoggerManager.test_mode!(level: :debug)

module Minitest
  class Test
    def before_setup
      super
      AIA::LoggerManager.clear_test_logs! if AIA::LoggerManager.test_mode?
    end
  end
end
