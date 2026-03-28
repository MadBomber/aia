# frozen_string_literal: true
# test/aia/cost_calculator_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class CostCalculatorTest < Minitest::Test
  MockModelInfo = Struct.new(:input_price_per_million, :output_price_per_million)

  def setup
    @model_info = MockModelInfo.new(3.0, 15.0)
  end

  def test_returns_unavailable_when_model_id_is_nil
    result = AIA::CostCalculator.calculate(model_id: nil, input_tokens: 100, output_tokens: 50)
    refute result[:available]
  end

  def test_returns_unavailable_when_model_not_found
    RubyLLM::Models.stubs(:find).returns(nil)
    result = AIA::CostCalculator.calculate(model_id: "unknown-model", input_tokens: 100, output_tokens: 50)
    refute result[:available]
  end

  def test_calculates_cost_correctly
    RubyLLM::Models.stubs(:find).returns(@model_info)

    result = AIA::CostCalculator.calculate(
      model_id:      "claude-sonnet",
      input_tokens:  1_000_000,
      output_tokens: 1_000_000
    )

    assert result[:available]
    assert_in_delta 3.0,  result[:input_cost],  0.0001
    assert_in_delta 15.0, result[:output_cost], 0.0001
    assert_in_delta 18.0, result[:total_cost],  0.0001
  end

  def test_returns_unavailable_on_standard_error
    RubyLLM::Models.stubs(:find).raises(StandardError, "lookup failed")

    result = AIA::CostCalculator.calculate(model_id: "any", input_tokens: 10, output_tokens: 10)
    refute result[:available]
    assert_equal "lookup failed", result[:error]
  end

  def test_zero_tokens_returns_zero_cost
    RubyLLM::Models.stubs(:find).returns(@model_info)

    result = AIA::CostCalculator.calculate(model_id: "claude-sonnet", input_tokens: 0, output_tokens: 0)

    assert result[:available]
    assert_in_delta 0.0, result[:total_cost], 0.0001
  end

  def test_returns_unavailable_when_prices_are_nil
    model_info = MockModelInfo.new(nil, nil)
    RubyLLM::Models.stubs(:find).returns(model_info)

    result = AIA::CostCalculator.calculate(model_id: "some-model", input_tokens: 100, output_tokens: 100)
    refute result[:available]
  end
end
