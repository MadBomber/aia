require_relative '../test_helper'

class ErrorsTest < Minitest::Test
  def test_configuration_error_is_defined
    assert defined?(AIA::ConfigurationError)
  end

  def test_configuration_error_is_standard_error_subclass
    assert AIA::ConfigurationError < StandardError
  end

  def test_configuration_error_can_be_raised
    error = assert_raises(AIA::ConfigurationError) do
      raise AIA::ConfigurationError, "bad config"
    end
    assert_equal "bad config", error.message
  end

  def test_configuration_error_can_be_caught_as_standard_error
    assert_raises(StandardError) do
      raise AIA::ConfigurationError, "test"
    end
  end
end
