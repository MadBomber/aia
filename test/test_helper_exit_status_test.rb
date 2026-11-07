# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "tmpdir"

# test_helper.rb keeps aia's exit calls from ending the test process. That
# guard must not also swallow Minitest's exit status at the end of a run.
class TestHelperExitStatusTest < Minitest::Test
  def test_failing_test_file_exits_non_zero
    output, status = run_probe("assert false")

    assert_match(/1 tests, 1 failures/, output)
    refute status.success?, "a failing test file exited 0"
  end

  private

  # Runs a one-test file that loads test_helper in a child process, from a
  # temp dir so its test_output.txt and coverage stay out of the repo.
  def run_probe(assertion)
    Dir.mktmpdir do |dir|
      probe = File.join(dir, "probe_test.rb")
      File.write(probe, <<~RUBY)
        require "test_helper"
        class ProbeTest < Minitest::Test
          def test_probe = #{assertion}
        end
      RUBY
      Open3.capture2e(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__),
                      "-I", __dir__, probe, chdir: dir, binmode: true)
    end
  end
end
