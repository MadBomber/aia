require_relative 'test_helper'
require 'open3'
require_relative '../lib/aia'

class CLITest < Minitest::Test
  BIN = File.expand_path('../bin/aia', __dir__)

  def test_help_option
    stdout, stderr, status = Open3.capture3('ruby', BIN, '--help')
    assert status.success?, "Expected exit status 0, got \\#{status.exitstatus}"
    assert_includes stdout, 'Usage:'
  end

  def test_version_option
    stdout, stderr, status = Open3.capture3('ruby', BIN, '--version')
    assert status.success?
    expected = AIA::VERSION + "\n"
    assert_equal expected, stdout
  end
end