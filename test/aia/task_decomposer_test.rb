# frozen_string_literal: true
# test/aia/task_decomposer_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class TaskDecomposerTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, debug: false),
      models: [OpenStruct.new(name: 'gpt-4o-mini')]
    )
    AIA.stubs(:config).returns(@config)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
  end

  def build_lead(reply_text)
    lead = mock('lead')
    lead.stubs(:name).returns("Alice")
    lead.stubs(:run).returns(OpenStruct.new(reply: reply_text))
    lead
  end

  def test_decompose_returns_steps_from_valid_json
    json = '[{"title": "Research AI safety", "assignee": "Alice"}, {"title": "Write report", "assignee": "Bob"}]'
    lead = build_lead(json)

    decomposer = AIA::TaskDecomposer.new(lead_robot: lead, ui_presenter: @ui)
    steps = decomposer.decompose("Research AI safety and write a report", ["Alice", "Bob"])

    assert_equal 2, steps.size
    assert_equal "Research AI safety", steps[0][:title]
    assert_equal "Alice", steps[0][:assignee]
    assert_equal "Write report", steps[1][:title]
    assert_equal "Bob", steps[1][:assignee]
  end

  def test_decompose_returns_empty_when_invalid_json
    lead = build_lead("I cannot parse this as JSON")

    decomposer = AIA::TaskDecomposer.new(lead_robot: lead, ui_presenter: @ui)
    steps = decomposer.decompose("Do something", ["Alice"])

    assert_empty steps
  end

  def test_decompose_falls_back_to_first_robot_for_unknown_assignee
    json = '[{"title": "Task", "assignee": "Unknown"}]'
    lead = build_lead(json)

    decomposer = AIA::TaskDecomposer.new(lead_robot: lead, ui_presenter: @ui)
    steps = decomposer.decompose("Do work", ["Alice", "Bob"])

    assert_equal "Alice", steps[0][:assignee]
  end

  def test_decompose_displays_info_via_ui_presenter
    lead = build_lead("[]")
    @ui.expects(:display_info).at_least_once

    decomposer = AIA::TaskDecomposer.new(lead_robot: lead, ui_presenter: @ui)
    decomposer.decompose("prompt", ["Alice"])
  end

  def test_decompose_returns_empty_on_json_parse_error
    json = '[{"title": "bad json'
    lead = build_lead(json)

    decomposer = AIA::TaskDecomposer.new(lead_robot: lead, ui_presenter: @ui)
    steps = decomposer.decompose("prompt", ["Alice"])

    assert_empty steps
  end
end
