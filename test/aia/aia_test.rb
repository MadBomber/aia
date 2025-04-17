require_relative '../test_helper'
require_relative '../../lib/aia'

class AIATest < Minitest::Test
  def test_run_method_exists
    assert_respond_to AIA, :run, "AIA should respond to the 'run' method"
  end
end
