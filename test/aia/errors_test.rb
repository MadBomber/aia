require_relative '../test_helper'

class ErrorsTest < Minitest::Test
  # Base error class
  def test_base_error_is_defined
    assert defined?(AIA::Error)
  end

  def test_base_error_is_standard_error_subclass
    assert AIA::Error < StandardError
  end

  # All domain errors inherit from AIA::Error
  AIA_ERROR_CLASSES = [
    AIA::ConfigurationError,
    AIA::PromptError,
    AIA::ToolError,
    AIA::MCPError,
    AIA::AdapterError,
    AIA::DirectiveError,
    AIA::GateError,
    AIA::OrchestratorError,
    AIA::DebateError,
    AIA::DecomposeError,
  ].freeze

  AIA_ERROR_CLASSES.each do |error_class|
    class_name = error_class.name.split('::').last

    define_method("test_#{class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_is_defined") do
      assert defined?(error_class)
    end

    define_method("test_#{class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_inherits_from_aia_error") do
      assert error_class < AIA::Error
    end

    define_method("test_#{class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_can_be_raised") do
      error = assert_raises(error_class) do
        raise error_class, "test #{class_name}"
      end
      assert_equal "test #{class_name}", error.message
    end

    define_method("test_#{class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_can_be_caught_as_standard_error") do
      assert_raises(StandardError) do
        raise error_class, "test"
      end
    end

    define_method("test_#{class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_can_be_caught_as_aia_error") do
      assert_raises(AIA::Error) do
        raise error_class, "test"
      end
    end
  end
end
