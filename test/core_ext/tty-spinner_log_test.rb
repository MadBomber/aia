require 'test_helper'
require 'stringio'

class TTY::SpinnerLogTest < Minitest::Test
  def setup
    @output = StringIO.new
    @spinner = TTY::Spinner.new(output: @output)
  end

  def test_log_method_exists
    assert_respond_to @spinner, :log
  end

  def test_log_prints_message
    @spinner.log("test message")
    assert_includes @output.string, "test message"
  end

  def test_log_preserves_spinner_state
    @spinner.start
    initial_state = @spinner.spinning?
    @spinner.log("test message")
    assert_equal initial_state, @spinner.spinning?
  end

  def test_log_clears_line_before_message
    @spinner.start
    @spinner.log("test message")
    output = @output.string
    assert_match /\r[^\n]*\n/, output
  end
end
