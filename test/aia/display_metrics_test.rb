# frozen_string_literal: true
# test/aia/display_metrics_test.rb

require_relative '../test_helper'

# Tests for the display_metrics and display_network_metrics methods
# in ChatLoop and MentionRouter. These verify that token usage, cost,
# and elapsed time are extracted and shown for both single-robot and
# multi-model network results.
#
# Token data lives on the raw RubyLLM::Message stored in
# RobotResult#raw (RobotLab::Message objects do not carry usage info).

class DisplayMetricsTest < Minitest::Test
  include AIA::ContentExtractor

  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(tokens: true, cost: true),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      output: OpenStruct.new(file: nil)
    )
    AIA.stubs(:config).returns(@config)

    @ui = mock('ui_presenter')
  end

  # --- extract_model_id ---

  def test_extract_model_id_from_model_id
    msg = OpenStruct.new(model_id: 'claude-sonnet-4', input_tokens: 10)
    loop_instance = build_chat_loop
    assert_equal 'claude-sonnet-4', loop_instance.send(:extract_model_id, msg)
  end

  def test_extract_model_id_falls_back_to_model
    msg = OpenStruct.new(model: 'gpt-4o-mini', input_tokens: 10)
    loop_instance = build_chat_loop
    assert_equal 'gpt-4o-mini', loop_instance.send(:extract_model_id, msg)
  end

  def test_extract_model_id_returns_nil_when_absent
    msg = OpenStruct.new(input_tokens: 10)
    loop_instance = build_chat_loop
    assert_nil loop_instance.send(:extract_model_id, msg)
  end

  # --- display_metrics: single robot ---
  # Token data is on result.raw (the original RubyLLM::Message).

  def test_display_metrics_single_robot
    raw_msg = OpenStruct.new(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini')
    result = OpenStruct.new(raw: raw_msg, robot_name: 'Spark')

    @ui.expects(:display_token_metrics).with(
      has_entries(model_id: 'gpt-4o-mini', input_tokens: 100, output_tokens: 50, elapsed: 3.5)
    )

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result, elapsed: 3.5)
  end

  def test_display_metrics_single_robot_falls_back_to_config_model
    raw_msg = OpenStruct.new(input_tokens: 100, output_tokens: 50)
    result = OpenStruct.new(raw: raw_msg, robot_name: 'Spark')

    @ui.expects(:display_token_metrics).with(
      has_entries(model_id: 'gpt-4o-mini')
    )

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result)
  end

  def test_display_metrics_passes_nil_elapsed_by_default
    raw_msg = OpenStruct.new(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini')
    result = OpenStruct.new(raw: raw_msg, robot_name: 'Spark')

    @ui.expects(:display_token_metrics).with(
      has_entries(elapsed: nil)
    )

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result)
  end

  def test_display_metrics_skipped_when_tokens_flag_off
    @config.flags.tokens = false

    raw_msg = OpenStruct.new(input_tokens: 10, output_tokens: 5)
    result = OpenStruct.new(raw: raw_msg)
    @ui.expects(:display_token_metrics).never

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result)
  end

  def test_display_metrics_skipped_when_raw_nil
    result = OpenStruct.new(raw: nil)
    @ui.expects(:display_token_metrics).never

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result)
  end

  # --- display_metrics: multi-model network ---
  # Each robot_result.raw holds the original RubyLLM::Message with
  # input_tokens, output_tokens, and model_id.
  # Each robot_result.duration holds the elapsed seconds.

  def test_display_metrics_network_result
    raw_a = OpenStruct.new(input_tokens: 100, output_tokens: 50, model_id: 'claude-sonnet-4')
    raw_b = OpenStruct.new(input_tokens: 200, output_tokens: 80, model_id: 'gpt-4o-mini')

    robot_a = OpenStruct.new(raw: raw_a, robot_name: 'Lyric', duration: 4.2, reply: 'A answer')
    robot_b = OpenStruct.new(raw: raw_b, robot_name: 'Spark', duration: 2.1, reply: 'B answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { lyric: robot_a, spark: robot_b }
    )

    @ui.expects(:display_multi_model_metrics).with { |list|
      list.size == 2 &&
        list[0][:model_id] == 'claude-sonnet-4' &&
        list[0][:display_name] == 'Lyric' &&
        list[0][:input_tokens] == 100 &&
        list[0][:elapsed] == 4.2 &&
        list[1][:model_id] == 'gpt-4o-mini' &&
        list[1][:display_name] == 'Spark' &&
        list[1][:input_tokens] == 200 &&
        list[1][:elapsed] == 2.1
    }

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  def test_display_metrics_network_skips_run_params
    raw_a = OpenStruct.new(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini')
    robot_a = OpenStruct.new(raw: raw_a, robot_name: 'Spark', duration: 1.5, reply: 'Answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { run_params: { message: 'test' }, spark: robot_a }
    )

    @ui.expects(:display_multi_model_metrics).with { |list|
      list.size == 1 && list[0][:display_name] == 'Spark'
    }

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  def test_display_metrics_network_skips_results_without_tokens
    robot_a = OpenStruct.new(raw: nil, robot_name: 'Spark', reply: 'Error happened')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { spark: robot_a }
    )

    @ui.expects(:display_multi_model_metrics).never

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  def test_display_metrics_network_handles_nil_duration
    raw_a = OpenStruct.new(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini')
    robot_a = OpenStruct.new(raw: raw_a, robot_name: 'Spark', reply: 'Answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { spark: robot_a }
    )

    @ui.expects(:display_multi_model_metrics).with { |list|
      list.size == 1 && list[0][:elapsed].nil?
    }

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  # --- similarity scoring in network metrics ---

  def test_display_network_metrics_includes_similarity_scores
    raw_a = OpenStruct.new(input_tokens: 100, output_tokens: 50, model_id: 'claude-sonnet-4')
    raw_b = OpenStruct.new(input_tokens: 200, output_tokens: 80, model_id: 'gpt-4o-mini')

    robot_a = OpenStruct.new(
      raw: raw_a, robot_name: 'Lyric', duration: 4.2,
      reply: 'Ruby is a dynamic programming language designed for productivity.'
    )
    robot_b = OpenStruct.new(
      raw: raw_b, robot_name: 'Spark', duration: 2.1,
      reply: 'Ruby is a dynamic programming language designed for productivity.'
    )

    flow_result = SimpleFlow::Result.new(
      :ok, context: { lyric: robot_a, spark: robot_b }
    )

    @ui.expects(:display_multi_model_metrics).with { |list|
      list.size == 2 &&
        list[0][:similarity].nil? &&
        list[1].key?(:similarity)
    }

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  def test_display_network_metrics_no_similarity_for_single_model
    raw_a = OpenStruct.new(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini')
    robot_a = OpenStruct.new(raw: raw_a, robot_name: 'Spark', duration: 1.5, reply: 'Answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { spark: robot_a }
    )

    @ui.expects(:display_multi_model_metrics).with { |list|
      list.size == 1 && !list[0].key?(:similarity)
    }

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  private

  def build_chat_loop
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)

    directive_processor = mock('directive_processor')
    rule_router = mock('rule_router')
    tracker = mock('tracker')

    AIA::ChatLoop.new(
      robot, @ui, directive_processor, rule_router,
      session_tracker: tracker
    )
  end
end
