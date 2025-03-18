require_relative '../test_helper'

class VersionTest < Minitest::Test
  def test_version_is_defined
    assert AIA::VERSION, "AIA::VERSION should be defined"
  end

  def test_version_format
    assert_match /^\d+\.\d+\.\d+$/, AIA::VERSION, "AIA::VERSION should be in the format 'X.Y.Z'"
  end
end
