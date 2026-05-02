# frozen_string_literal: true
# test/aia/prompt_decomposer_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/prompt_decomposer'

class PromptDecomposerTest < Minitest::Test
  def setup
    @mock_robot = mock('robot')
    @decomposer = AIA::PromptDecomposer.new(@mock_robot)
    @decomposer.stubs(:build_probe_robot).returns(@mock_robot)
  end

  # ── structured output path (model supports with_schema) ───────────────────

  def test_decompose_uses_with_schema_when_model_supports_structured_output
    @decomposer.stubs(:structured_output?).returns(true)
    @mock_robot.stubs(:with_schema)
    mock_result = OpenStruct.new(reply: { 'subtasks' => ['task one', 'task two'] })
    @mock_robot.expects(:run).with(
      Not(regexp_matches(/Respond with ONLY/)),
      mcp: :none, tools: :none
    ).returns(mock_result)

    result = @decomposer.decompose("Build something complex")

    assert_equal ['task one', 'task two'], result
  end

  def test_decompose_returns_subtasks_from_hash_reply
    @decomposer.stubs(:structured_output?).returns(true)
    @mock_robot.stubs(:with_schema)
    mock_result = OpenStruct.new(reply: { 'subtasks' => ['Set up auth', 'Design schema', 'Create endpoints'] })
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Build a web app")

    assert_equal 3, result.length
    assert_equal 'Set up auth',      result[0]
    assert_equal 'Design schema',    result[1]
    assert_equal 'Create endpoints', result[2]
  end

  def test_decompose_filters_non_string_elements
    @decomposer.stubs(:structured_output?).returns(true)
    @mock_robot.stubs(:with_schema)
    mock_result = OpenStruct.new(reply: { 'subtasks' => ['valid', 42, nil, 'another', true, ''] })
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Complex request")

    assert_equal ['valid', 'another'], result
  end

  def test_decompose_returns_empty_for_empty_subtasks_hash
    @decomposer.stubs(:structured_output?).returns(true)
    @mock_robot.stubs(:with_schema)
    mock_result = OpenStruct.new(reply: { 'subtasks' => [] })
    @mock_robot.stubs(:run).returns(mock_result)

    assert_equal [], @decomposer.decompose("Simple question")
  end

  # ── fallback path (model does not support structured output) ───────────────

  def test_decompose_appends_json_instruction_when_no_structured_output
    @decomposer.stubs(:structured_output?).returns(false)
    mock_result = OpenStruct.new(reply: '{"subtasks": ["task a", "task b"]}')
    @mock_robot.expects(:run).with(
      regexp_matches(/Respond with ONLY a JSON object/),
      mcp: :none, tools: :none
    ).returns(mock_result)

    result = @decomposer.decompose("Build something")

    assert_equal ['task a', 'task b'], result
  end

  def test_decompose_parses_json_string_reply_on_fallback_path
    @decomposer.stubs(:structured_output?).returns(false)
    mock_result = OpenStruct.new(reply: '{"subtasks": ["task one", "task two"]}')
    @mock_robot.stubs(:run).returns(mock_result)

    result = @decomposer.decompose("Do many things")

    assert_equal ['task one', 'task two'], result
  end

  def test_decompose_strips_markdown_fences_from_json_reply
    @decomposer.stubs(:structured_output?).returns(false)
    mock_result = OpenStruct.new(reply: "```json\n{\"subtasks\": [\"task one\"]}\n```")
    @mock_robot.stubs(:run).returns(mock_result)

    assert_equal ['task one'], @decomposer.decompose("Something")
  end

  # ── shared behaviour ───────────────────────────────────────────────────────

  def test_decompose_returns_empty_when_robot_raises
    @decomposer.stubs(:structured_output?).returns(false)
    @mock_robot.stubs(:run).raises(StandardError, "connection failed")

    assert_equal [], @decomposer.decompose("Some prompt")
  end

  def test_decompose_returns_empty_when_reply_is_unparseable
    @decomposer.stubs(:structured_output?).returns(false)
    mock_result = OpenStruct.new(reply: "this is not json at all")
    @mock_robot.stubs(:run).returns(mock_result)

    assert_equal [], @decomposer.decompose("Some prompt")
  end

  def test_decompose_passes_mcp_none_and_tools_none
    @decomposer.stubs(:structured_output?).returns(false)
    mock_result = OpenStruct.new(reply: '{"subtasks": []}')
    @mock_robot.expects(:run).with(anything, mcp: :none, tools: :none).returns(mock_result)

    @decomposer.decompose("Test prompt")
  end

  # ── synthesize ─────────────────────────────────────────────────────────────

  def test_synthesize_calls_robot_with_formatted_results
    @mock_robot.expects(:run).with(
      regexp_matches(/Sub-task 1.*Result A.*Sub-task 2.*Result B/m),
      mcp: :none, tools: :none
    ).returns(OpenStruct.new(reply: 'Synthesized answer'))

    result = @decomposer.synthesize("Original prompt", ['Result A', 'Result B'])

    assert_equal 'Synthesized answer', result.reply
  end

  def test_synthesize_includes_original_prompt
    @mock_robot.expects(:run).with(
      regexp_matches(/Original request: My complex question/),
      mcp: :none, tools: :none
    ).returns(OpenStruct.new(reply: 'Answer'))

    @decomposer.synthesize("My complex question", ['Result 1'])
  end
end
