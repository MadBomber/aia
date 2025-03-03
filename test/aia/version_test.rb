# frozen_string_literal: true

require "test_helper"

class AIA::VersionTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::AIA::VERSION
    assert_match(/\d+\.\d+\.\d+/, ::AIA::VERSION)
  end
end
