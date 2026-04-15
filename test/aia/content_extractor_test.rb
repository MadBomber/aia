# frozen_string_literal: true
# test/aia/content_extractor_test.rb

require_relative '../test_helper'
require 'tempfile'

# Minimal host class to exercise ContentExtractor in isolation
class ContentExtractorTestHost
  include AIA::ContentExtractor

  # Stub optional callers so present_result works without full ChatLoop
  def display_metrics(*); end
  def speak(*); end
end

class ContentExtractorTest < Minitest::Test
  def setup
    @host = ContentExtractorTestHost.new
    AIA.stubs(:config).returns(OpenStruct.new(
      models: [OpenStruct.new(name: 'test-model')],
      output: OpenStruct.new(file: nil),
      flags: OpenStruct.new(tokens: false)
    ))
  end

  def teardown
    Mocha::Mockery.instance.teardown
  end

  # ---------------------------------------------------------------------------
  # extract_content — plain String
  # ---------------------------------------------------------------------------

  def test_extract_content_returns_string_unchanged
    assert_equal "hello world", @host.extract_content("hello world")
  end

  def test_extract_content_returns_empty_string_unchanged
    assert_equal "", @host.extract_content("")
  end

  # ---------------------------------------------------------------------------
  # extract_content — object responding to :reply
  # ---------------------------------------------------------------------------

  def test_extract_content_prefers_reply
    obj = OpenStruct.new(reply: "the reply", content: "not this")
    assert_equal "the reply", @host.extract_content(obj)
  end

  def test_extract_content_reply_takes_priority_over_last_text_content
    obj = OpenStruct.new(reply: "reply wins", last_text_content: "ignored")
    assert_equal "reply wins", @host.extract_content(obj)
  end

  # ---------------------------------------------------------------------------
  # extract_content — object responding to :last_text_content (no :reply)
  # ---------------------------------------------------------------------------

  def test_extract_content_uses_last_text_content
    obj = OpenStruct.new(last_text_content: "text content")
    assert_equal "text content", @host.extract_content(obj)
  end

  def test_extract_content_last_text_content_takes_priority_over_content
    obj = OpenStruct.new(last_text_content: "text wins", content: "ignored")
    assert_equal "text wins", @host.extract_content(obj)
  end

  # ---------------------------------------------------------------------------
  # extract_content — object responding to :content only
  # ---------------------------------------------------------------------------

  def test_extract_content_falls_back_to_content
    obj = OpenStruct.new(content: "plain content")
    assert_equal "plain content", @host.extract_content(obj)
  end

  # ---------------------------------------------------------------------------
  # extract_content — unknown object falls back to to_s
  # ---------------------------------------------------------------------------

  def test_extract_content_falls_back_to_to_s
    obj = Object.new
    def obj.to_s; "stringified"; end
    assert_equal "stringified", @host.extract_content(obj)
  end

  def test_extract_content_integer_falls_back_to_to_s
    assert_equal "42", @host.extract_content(42)
  end

  # ---------------------------------------------------------------------------
  # format_duration — under 60 seconds
  # ---------------------------------------------------------------------------

  def test_format_duration_seconds
    assert_equal "3.5s", @host.format_duration(3.5)
  end

  def test_format_duration_zero
    assert_equal "0.0s", @host.format_duration(0.0)
  end

  def test_format_duration_just_under_sixty
    result = @host.format_duration(59.9)
    assert_equal "59.9s", result
  end

  def test_format_duration_one_second
    assert_equal "1.0s", @host.format_duration(1.0)
  end

  # ---------------------------------------------------------------------------
  # format_duration — over 60 seconds
  # ---------------------------------------------------------------------------

  def test_format_duration_minutes_and_seconds
    result = @host.format_duration(90.0)
    assert_match(/1m/, result)
    assert_match(/30/, result)
  end

  def test_format_duration_exactly_sixty
    result = @host.format_duration(60.0)
    assert_match(/1m/, result)
  end

  def test_format_duration_large_value
    result = @host.format_duration(125.5)
    assert_match(/2m/, result)
  end

  # ---------------------------------------------------------------------------
  # format_duration — nil
  # ---------------------------------------------------------------------------

  def test_format_duration_nil_returns_zero_string
    assert_equal "0.0s", @host.format_duration(nil)
  end

  # ---------------------------------------------------------------------------
  # extract_network_content — skips :run_params key
  # ---------------------------------------------------------------------------

  def test_extract_network_content_skips_run_params
    run_params = OpenStruct.new(reply: "ignore this")
    robot_result = OpenStruct.new(reply: "real response", robot_name: "Tobor", duration: 1.2)
    flow_result = OpenStruct.new(context: { run_params: run_params, tobor: robot_result })
    result = @host.extract_network_content(flow_result)
    refute_match(/ignore this/, result)
    assert_match(/real response/, result)
  end

  # ---------------------------------------------------------------------------
  # extract_network_content — empty content skipped
  # ---------------------------------------------------------------------------

  def test_extract_network_content_skips_empty_reply
    robot_result = OpenStruct.new(reply: "", robot_name: "Tobor", duration: nil)
    flow_result = OpenStruct.new(context: { tobor: robot_result })
    assert_equal "", @host.extract_network_content(flow_result)
  end

  def test_extract_network_content_skips_nil_content
    robot_result = OpenStruct.new(reply: nil, robot_name: "Tobor", duration: nil)
    flow_result = OpenStruct.new(context: { tobor: robot_result })
    assert_equal "", @host.extract_network_content(flow_result)
  end

  # ---------------------------------------------------------------------------
  # extract_network_content — duration included in header when present
  # ---------------------------------------------------------------------------

  def test_extract_network_content_includes_duration
    robot_result = OpenStruct.new(reply: "response text", robot_name: "Tobor", duration: 2.5)
    flow_result = OpenStruct.new(context: { tobor: robot_result })
    result = @host.extract_network_content(flow_result)
    assert_match(/2\.5s/, result)
    assert_match(/response text/, result)
  end

  def test_extract_network_content_no_duration_omits_timing
    robot_result = OpenStruct.new(reply: "response text", robot_name: "Tobor")
    flow_result = OpenStruct.new(context: { tobor: robot_result })
    result = @host.extract_network_content(flow_result)
    refute_match(/\d+\.\d+s/, result)
    assert_match(/response text/, result)
  end

  # ---------------------------------------------------------------------------
  # extract_network_content — label logic: robot_name vs task_name
  # ---------------------------------------------------------------------------

  def test_extract_network_content_uses_robot_name_when_differs_from_task_name
    robot_result = OpenStruct.new(reply: "response", robot_name: "FriendlyBot", duration: nil)
    flow_result = OpenStruct.new(context: { tobor: robot_result })
    result = @host.extract_network_content(flow_result)
    assert_match(/FriendlyBot/, result)
    assert_match(/tobor/, result)
  end

  def test_extract_network_content_uses_task_name_when_robot_name_matches
    robot_result = OpenStruct.new(reply: "response", robot_name: "tobor", duration: nil)
    flow_result = OpenStruct.new(context: { tobor: robot_result })
    result = @host.extract_network_content(flow_result)
    assert_match(/tobor/, result)
  end

  def test_extract_network_content_uses_content_fallback_when_no_reply
    robot_result = OpenStruct.new(content: "content fallback", duration: nil)
    flow_result = OpenStruct.new(context: { worker: robot_result })
    result = @host.extract_network_content(flow_result)
    assert_match(/content fallback/, result)
  end

  def test_extract_network_content_multiple_robots_joined_with_double_newline
    r1 = OpenStruct.new(reply: "first", robot_name: "r1", duration: nil)
    r2 = OpenStruct.new(reply: "second", robot_name: "r2", duration: nil)
    flow_result = OpenStruct.new(context: { robot1: r1, robot2: r2 })
    result = @host.extract_network_content(flow_result)
    assert_match(/first/, result)
    assert_match(/second/, result)
    assert_match(/\n\n/, result)
  end

  # ---------------------------------------------------------------------------
  # extract_network_content — falls through to extract_content when SimpleFlow
  # ---------------------------------------------------------------------------

  def test_extract_content_delegates_to_extract_network_content_for_simple_flow_result
    skip "SimpleFlow::Result not available in test env" unless defined?(SimpleFlow::Result)

    robot_result = OpenStruct.new(reply: "from network", robot_name: "Bot", duration: nil)
    flow_result = SimpleFlow::Result.new(nil, context: { bot: robot_result })
    result = @host.extract_content(flow_result)
    assert_match(/from network/, result)
  end

  # ---------------------------------------------------------------------------
  # output_to_file — writes when file configured
  # ---------------------------------------------------------------------------

  def test_output_to_file_appends_to_configured_file
    Tempfile.create('ce_test') do |f|
      AIA.config.output.file = f.path
      @host.output_to_file("test content")
      assert_match(/AI: test content/, File.read(f.path))
    end
  end

  def test_output_to_file_appends_not_overwrites
    Tempfile.create('ce_append') do |f|
      f.write("existing line\n")
      f.flush
      AIA.config.output.file = f.path
      @host.output_to_file("new content")
      body = File.read(f.path)
      assert_match(/existing line/, body)
      assert_match(/AI: new content/, body)
    end
  end

  # ---------------------------------------------------------------------------
  # output_to_file — no-op when no file
  # ---------------------------------------------------------------------------

  def test_output_to_file_noop_when_no_output_file
    AIA.config.output.file = nil
    assert_nil @host.output_to_file("ignored")
  end

  # ---------------------------------------------------------------------------
  # present_result — integration-level smoke test
  # ---------------------------------------------------------------------------

  def test_present_result_returns_content_string
    ui = mock('ui_presenter')
    ui.expects(:display_ai_response).with("hello")
    ui.expects(:display_separator)

    result = @host.present_result("hello", ui_presenter: ui)
    assert_equal "hello", result
  end

  def test_present_result_uses_streamed_content_when_provided
    ui = mock('ui_presenter')
    ui.expects(:display_ai_response).never
    ui.expects(:display_separator)

    result = @host.present_result("ignored_result", streamed_content: "streamed", ui_presenter: ui)
    assert_equal "streamed", result
  end

  def test_present_result_records_turn_when_tracker_and_prompt_given
    ui = mock('ui_presenter')
    ui.stubs(:display_ai_response)
    ui.stubs(:display_separator)

    tracker = mock('tracker')
    tracker.expects(:record_turn).with(
      model: 'test-model',
      input: 'my prompt',
      result: 'response',
      decisions: nil,
      elapsed: nil
    )

    @host.present_result("response", prompt: "my prompt", ui_presenter: ui, tracker: tracker)
  end

  def test_present_result_skips_tracker_when_prompt_absent
    ui = mock('ui_presenter')
    ui.stubs(:display_ai_response)
    ui.stubs(:display_separator)

    tracker = mock('tracker')
    tracker.expects(:record_turn).never

    @host.present_result("response", ui_presenter: ui, tracker: tracker)
  end
end
