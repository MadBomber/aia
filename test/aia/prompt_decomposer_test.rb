# frozen_string_literal: true
# test/aia/prompt_decomposer_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class PromptDecomposerTest < Minitest::Test
  def setup
    @mock_robot = mock('robot')
    @decomposer = AIA::PromptDecomposer.new(@mock_robot)
  end

  def teardown
    super
  end

  def test_decompose_returns_empty_array_when_robot_returns_invalid_json
    mock_result = OpenStruct.new(reply: "this is not valid json at all")
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Build a web app with auth and database")

    assert_equal [], result
  end

  def test_decompose_returns_array_of_strings_when_robot_returns_valid_json_array
    subtasks = [
      "Set up authentication system",
      "Design database schema",
      "Create API endpoints"
    ]
    mock_result = OpenStruct.new(reply: JSON.generate(subtasks))
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Build a web app with auth and database")

    assert_equal 3, result.length
    assert_equal "Set up authentication system", result[0]
    assert_equal "Design database schema", result[1]
    assert_equal "Create API endpoints", result[2]
  end

  def test_decompose_returns_empty_array_when_json_is_not_an_array
    mock_result = OpenStruct.new(reply: '{"task": "something"}')
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Build something")

    assert_equal [], result
  end

  def test_decompose_filters_out_non_string_elements
    mixed_array = ["valid task", 42, nil, "another task", true, ""]
    mock_result = OpenStruct.new(reply: JSON.generate(mixed_array))
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Complex request")

    assert_equal 2, result.length
    assert_equal "valid task", result[0]
    assert_equal "another task", result[1]
  end

  def test_decompose_returns_empty_array_when_robot_raises_exception
    @mock_robot.stubs(:run).raises(StandardError, "connection failed")

    result = @decomposer.decompose("Some prompt")

    assert_equal [], result
  end

  def test_decompose_returns_empty_array_for_empty_json_array
    mock_result = OpenStruct.new(reply: '[]')
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Simple question")

    assert_equal [], result
  end

  def test_decompose_uses_content_method_as_fallback
    mock_result = mock('result')
    mock_result.stubs(:respond_to?).with(:reply).returns(false)
    mock_result.stubs(:respond_to?).with(:content).returns(true)
    mock_result.stubs(:content).returns('["task one", "task two"]')
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Complex request")

    assert_equal 2, result.length
    assert_equal "task one", result[0]
    assert_equal "task two", result[1]
  end

  def test_decompose_uses_to_s_as_last_resort
    mock_result = mock('result')
    mock_result.stubs(:respond_to?).with(:reply).returns(false)
    mock_result.stubs(:respond_to?).with(:content).returns(false)
    mock_result.stubs(:to_s).returns('["fallback task"]')
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Some prompt")

    assert_equal 1, result.length
    assert_equal "fallback task", result[0]
  end

  def test_synthesize_calls_robot_with_formatted_results
    results = ["Result A", "Result B"]

    @mock_robot.expects(:run).with(
      regexp_matches(/Sub-task 1.*Result A.*Sub-task 2.*Result B/m),
      mcp: :none, tools: :none
    ).returns(OpenStruct.new(reply: "Synthesized answer"))

    result = @decomposer.synthesize("Original prompt", results)

    assert_equal "Synthesized answer", result.reply
  end

  def test_synthesize_includes_original_prompt_in_request
    @mock_robot.expects(:run).with(
      regexp_matches(/Original request: My complex question/),
      mcp: :none, tools: :none
    ).returns(OpenStruct.new(reply: "Answer"))

    @decomposer.synthesize("My complex question", ["Result 1"])
  end

  def test_decompose_passes_correct_options_to_robot_run
    mock_result = OpenStruct.new(reply: '[]')
    @mock_robot.expects(:run).with(
      anything,
      mcp: :none, tools: :none
    ).returns(mock_result)

    @decomposer.decompose("Test prompt")
  end
end
