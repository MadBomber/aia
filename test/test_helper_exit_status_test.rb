# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "tmpdir"

# test_helper.rb keeps aia's exit calls from ending the test process. That
# guard must not swallow Minitest's own exit status: neither the non-zero it
# returns when a test fails, nor the exit it raises for an unknown
# command-line option. Both must still reach the shell.
class TestHelperExitStatusTest < Minitest::Test
  def test_failing_test_file_exits_non_zero
    output, status = run_probe(<<~RUBY)
      require "test_helper"
      class ProbeTest < Minitest::Test
        def test_probe = assert(false)
      end
    RUBY

    assert_match(/1 tests, 1 failures/, output)
    refute status.success?, "a failing test file exited 0"
  end

  def test_unknown_cli_option_exits_non_zero
    _output, status = run_probe(<<~RUBY, "--no-such-option")
      require "test_helper"
      class ProbeTest < Minitest::Test
        def test_probe = assert(true)
      end
    RUBY

    refute status.success?, "an unknown command-line option exited 0"
  end

  private

  # Runs a probe file in a child process from a temp dir, so its
  # test_output.txt and coverage stay out of the repo and a leftover copy
  # under test/tmp is never globbed (the file is not named *_test.rb). The
  # child drops DEBUG_ME so the parent's debug output cannot pollute the
  # probe, and passing it to Open3 as nil leaves this process's own ENV
  # untouched. RUBYOPT and RUBYLIB are kept: the probe loads aia, whose
  # pinned gems only resolve under the inherited Bundler setup.
  def run_probe(source, *)
    Dir.mktmpdir do |dir|
      probe = File.join(dir, "probe.rb")
      File.write(probe, source)
      Open3.capture2e({ "DEBUG_ME" => nil }, RbConfig.ruby,
                      "-I", File.expand_path("../lib", __dir__),
                      "-I", __dir__, probe, *, chdir: dir, binmode: true)
    end
  end
end
