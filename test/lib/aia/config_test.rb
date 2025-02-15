require 'test_helper'

class AIA::ConfigTest < Minitest::Test
  def setup
    @config = AIA::Config.new
  end

  def test_config_initialization
    assert_instance_of AIA::Config, @config
  end

  def test_disable_warnings
    assert AIA::Config.disable_warnings
  end
end
