# frozen_string_literal: true
# test/aia/prompt_decomposer_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/prompt_decomposer'

class PromptDecomposerTest < Minitest::Test
  def setup
    @mock_robot = mock('robot')
    @decomposer = AIA::PromptDecomposer.new(@mock_robot)
    # decompose builds a probe robot internally; redirect it to @mock_robot.
    @decomposer.stubs(:build_probe_robot).returns(@mock_robot)
    # with_schema is called on the probe before run; the mock must allow it.
    # Robot#with_schema delegates to the underlying chat and returns self.
    @mock_robot.stubs(:with_schema).returns(@mock_robot)
  end

  # with_schema makes the chat auto-parse JSON, so result.reply is a Hash.
  # Tests use { 'subtasks' => [...] } to reflect that real behavior.

  def test_decompose_returns_array_of_strings
    mock_result = OpenStruct.new(reply: { 'subtasks' => ['Set up auth', 'Design schema', 'Create endpoints'] })
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Build a web app with auth and database")

    assert_equal 3, result.length
    assert_equal 'Set up auth',       result[0]
    assert_equal 'Design schema',     result[1]
    assert_equal 'Create endpoints',  result[2]
  end

  def test_decompose_returns_empty_array_for_empty_subtasks
    mock_result = OpenStruct.new(reply: { 'subtasks' => [] })
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Simple question")

    assert_equal [], result
  end

  def test_decompose_filters_out_non_string_elements
    mock_result = OpenStruct.new(reply: { 'subtasks' => ['valid task', 42, nil, 'another task', true, ''] })
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Complex request")

    assert_equal 2, result.length
    assert_equal 'valid task',    result[0]
    assert_equal 'another task',  result[1]
  end

  def test_decompose_returns_empty_array_when_robot_raises_exception
    @mock_robot.stubs(:run).raises(StandardError, "connection failed")

    result = @decomposer.decompose("Some prompt")

    assert_equal [], result
  end

  def test_decompose_returns_empty_array_when_reply_is_unexpected_type
    mock_result = OpenStruct.new(reply: "unexpected string")
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Some prompt")

    assert_equal [], result
  end

  def test_decompose_passes_correct_options_to_robot_run
    mock_result = OpenStruct.new(reply: { 'subtasks' => [] })
    @mock_robot.expects(:run).with(anything, mcp: :none, tools: :none).returns(mock_result)

    @decomposer.decompose("Test prompt")
  end

  def test_decompose_calls_with_schema_before_run
    mock_result = OpenStruct.new(reply: { 'subtasks' => [] })
    @mock_robot.unstub(:with_schema)
    @mock_robot.expects(:with_schema).with(AIA::PromptDecomposer::SUBTASKS_SCHEMA).returns(@mock_robot)
    @mock_robot.stubs(:run).returns(mock_result)

    @decomposer.decompose("Test prompt")
  end

  def test_synthesize_calls_robot_with_formatted_results
    results = ['Result A', 'Result B']

    @mock_robot.expects(:run).with(
      regexp_matches(/Sub-task 1.*Result A.*Sub-task 2.*Result B/m),
      mcp: :none, tools: :none
    ).returns(OpenStruct.new(reply: 'Synthesized answer'))

    result = @decomposer.synthesize("Original prompt", results)

    assert_equal 'Synthesized answer', result.reply
  end

  def test_synthesize_includes_original_prompt_in_request
    @mock_robot.expects(:run).with(
      regexp_matches(/Original request: My complex question/),
      mcp: :none, tools: :none
    ).returns(OpenStruct.new(reply: 'Answer'))

    @decomposer.synthesize("My complex question", ['Result 1'])
  end
end
