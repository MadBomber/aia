require 'test_helper'

class AIA::ConfigTest < Minitest::Test
  def setup
    @config = AIA::Config.new
  end

  def test_initialize
    assert_instance_of AIA::Config, @config
  end

  def test_disable_warnings
    assert_nil AIA::Config.disable_warnings
  end
end
