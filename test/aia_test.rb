# frozen_string_literal: true

require "test_helper"

class AIATest < Minitest::Test
  def setup
    super
    @original_config = AIA.config
    AIA.config = AIA::Config.new
  end

  def teardown
    AIA.config = @original_config
    super
  end

  def test_that_it_has_a_version_number
    refute_nil ::AIA::VERSION
  end

  def test_it_does_something_useful
    assert true
  end
end
