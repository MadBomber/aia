# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "tmpdir"

# test_helper.rb keeps aia's exit calls from ending the test process. That
# guard must not also swallow Minitest's exit status at the end of a run.
class TestHelperExitStatusTest < Minitest::Test
  def test_failing_test_file_exits_non_zero
    output, status = run_failing_probe

    assert_match(/1 tests, 1 failures/, output)
    refute status.success?, "a failing test file exited 0"
  end

  private

  # Runs a file with one failing test in a child process, from a temp dir so
  # its test_output.txt and coverage stay out of the repo. The file is not
  # named *_test.rb, so a leftover copy under test/tmp is never globbed.
  def run_failing_probe
    Dir.mktmpdir do |dir|
      probe = File.join(dir, "probe.rb")
      File.write(probe, <<~RUBY)
        require "test_helper"
        class ProbeTest < Minitest::Test
          def test_probe = assert(false)
        end
      RUBY
      Open3.capture2e(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__),
                      "-I", __dir__, probe, chdir: dir, binmode: true)
    end
  end
end
