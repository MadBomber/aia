require 'test_helper'
require 'stringio'

class SpinnerLogTest < Minitest::Test
  def setup
    @output = StringIO.new
    @spinner = TTY::Spinner.new(output: @output)
  end

  def test_log_method_exists
    assert_respond_to @spinner, :log
  end

  def test_log_prints_message
    @spinner.log("test message")
    assert_match /test message\n/, @output.string
  end

  def test_log_preserves_spinner_state
    @spinner.success
    @spinner.log("test message")
    assert @spinner.success?
  end

  def test_log_clears_line_before_message
    @spinner.spin
    @spinner.log("test message")
    assert_match /\rtest message\n/, @output.string
  end
end
