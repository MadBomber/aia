# frozen_string_literal: true

# test/aia/timing_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class TimingTest < Minitest::Test
  def test_timed_returns_block_result_and_elapsed
    result, elapsed = AIA::Timing.timed { :done }

    assert_equal :done, result
    assert_kind_of Float, elapsed
    assert_operator elapsed, :>=, 0.0
  end

  def test_timed_measures_wall_clock
    _result, elapsed = AIA::Timing.timed { sleep 0.01 }
    assert_operator elapsed, :>=, 0.01
  end

  def test_timed_propagates_exceptions
    assert_raises(RuntimeError) { AIA::Timing.timed { raise 'boom' } }
  end
end
