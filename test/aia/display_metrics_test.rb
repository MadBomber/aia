# frozen_string_literal: true

# test/aia/display_metrics_test.rb

require_relative '../test_helper'

# Tests for the display_metrics and display_network_metrics methods
# in ChatLoop and MentionRouter. These verify that token usage, cost,
# and elapsed time are extracted and shown for both single-robot and
# multi-model network results.
#
# Results are real RobotLab::RobotResult objects wrapping ruby_llm 2.x
# RubyLLM::Message objects, the shape aia receives at runtime.

class DisplayMetricsTest < Minitest::Test
  include AIA::ContentExtractor
  include LLMResultFactory

  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(tokens: true, cost: true),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      output: OpenStruct.new(file: nil)
    )
    AIA.stubs(:config).returns(@config)

    @ui = mock('ui_presenter')
  end

  # --- Utility.token_usage ---

  def test_token_usage_reads_robot_result_counts_and_raw_model
    usage = AIA::Utility.token_usage(robot_result(input_tokens: 1000, output_tokens: 20, model_id: 'gpt-4o'))
    assert_equal({ input_tokens: 1000, output_tokens: 20, model_id: 'gpt-4o' }, usage)
  end

  def test_token_usage_reads_ruby_llm_2_message_tokens
    result = OpenStruct.new(raw: ruby_llm_message(input_tokens: 7, output_tokens: 3, model_id: 'gpt-4o-mini'))
    assert_equal({ input_tokens: 7, output_tokens: 3, model_id: 'gpt-4o-mini' }, AIA::Utility.token_usage(result))
  end

  def test_token_usage_nil_when_no_tokens_reported
    assert_nil AIA::Utility.token_usage(robot_result(input_tokens: 0, output_tokens: 0))
    assert_nil AIA::Utility.token_usage(OpenStruct.new(raw: nil))
  end

  # --- display_metrics: single robot ---

  def test_display_metrics_single_robot
    result = robot_result(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini', robot_name: 'Spark')

    @ui.expects(:display_token_metrics).with(
      has_entries(model_id: 'gpt-4o-mini', input_tokens: 100, output_tokens: 50, elapsed: 3.5)
    )

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result, elapsed: 3.5)
  end

  def test_display_metrics_single_robot_falls_back_to_config_model
    result = robot_result(input_tokens: 100, output_tokens: 50, robot_name: 'Spark')

    @ui.expects(:display_token_metrics).with(
      has_entries(model_id: 'gpt-4o-mini')
    )

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result)
  end

  def test_display_metrics_passes_nil_elapsed_by_default
    result = robot_result(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini', robot_name: 'Spark')

    @ui.expects(:display_token_metrics).with(
      has_entries(elapsed: nil)
    )

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, result)
  end

  def test_display_metrics_skipped_when_tokens_flag_off
    @config.flags.tokens = false

    result = robot_result(input_tokens: 10, output_tokens: 5)
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
  # Token counts come from each RobotResult, the model id from its raw
  # RubyLLM::Message, and the elapsed seconds from RobotResult#duration.

  def test_display_metrics_network_result

    robot_a = robot_result(input_tokens: 100, output_tokens: 50, model_id: 'claude-sonnet-4', robot_name: 'Lyric', duration: 4.2, reply: 'A answer')
    robot_b = robot_result(input_tokens: 200, output_tokens: 80, model_id: 'gpt-4o-mini', robot_name: 'Spark', duration: 2.1, reply: 'B answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { lyric: robot_a, spark: robot_b }
    )

    @ui.expects(:display_multi_model_metrics).with do |list|
      list.size == 2 &&
        list[0][:model_id] == 'claude-sonnet-4' &&
        list[0][:display_name] == 'Lyric' &&
        list[0][:input_tokens] == 100 &&
        list[0][:elapsed] == 4.2 &&
        list[1][:model_id] == 'gpt-4o-mini' &&
        list[1][:display_name] == 'Spark' &&
        list[1][:input_tokens] == 200 &&
        list[1][:elapsed] == 2.1
    end

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  def test_display_metrics_network_skips_run_params
    robot_a = robot_result(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini', robot_name: 'Spark', duration: 1.5, reply: 'Answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { run_params: { message: 'test' }, spark: robot_a }
    )

    @ui.expects(:display_multi_model_metrics).with do |list|
      list.size == 1 && list[0][:display_name] == 'Spark'
    end

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
    robot_a = robot_result(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini', robot_name: 'Spark', reply: 'Answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { spark: robot_a }
    )

    @ui.expects(:display_multi_model_metrics).with do |list|
      list.size == 1 && list[0][:elapsed].nil?
    end

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  # --- similarity scoring in network metrics ---

  def test_display_network_metrics_includes_similarity_scores

    robot_a = robot_result(input_tokens: 100, output_tokens: 50, model_id: 'claude-sonnet-4', robot_name: 'Lyric', duration: 4.2, reply: 'Ruby is a dynamic programming language designed for productivity.')
    robot_b = robot_result(input_tokens: 200, output_tokens: 80, model_id: 'gpt-4o-mini', robot_name: 'Spark', duration: 2.1, reply: 'Ruby is a dynamic programming language designed for productivity.')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { lyric: robot_a, spark: robot_b }
    )

    @ui.expects(:display_multi_model_metrics).with do |list|
      list.size == 2 &&
        list[0][:similarity].nil? &&
        list[1].key?(:similarity)
    end

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  def test_display_network_metrics_no_similarity_for_single_model
    robot_a = robot_result(input_tokens: 100, output_tokens: 50, model_id: 'gpt-4o-mini', robot_name: 'Spark', duration: 1.5, reply: 'Answer')

    flow_result = SimpleFlow::Result.new(
      :ok, context: { spark: robot_a }
    )

    @ui.expects(:display_multi_model_metrics).with do |list|
      list.size == 1 && !list[0].key?(:similarity)
    end

    loop_instance = build_chat_loop
    loop_instance.send(:display_metrics, flow_result)
  end

  private

  def build_chat_loop
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)

    directive_processor = mock('directive_processor')
    tracker = mock('tracker')

    AIA::ChatLoop.new(
      robot, @ui, directive_processor,
      session_tracker: tracker
    )
  end
end
