# frozen_string_literal: true
# test/aia/mention_router_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class MentionRouterTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(chat: true, debug: false, verbose: false, tokens: false),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      mcp_servers: [],
      audio: OpenStruct.new(speak_command: nil),
      output: OpenStruct.new(file: nil, append: false)
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:speak?).returns(false)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_ai_response)
    @ui.stubs(:display_separator)

    @tracker = mock('session_tracker')
    @tracker.stubs(:record_turn)

    @streaming_runner = mock('streaming_runner')

    @handler = AIA::MentionRouter.new(
      ui_presenter: @ui,
      tracker: @tracker,
      streaming_runner: @streaming_runner
    )
  end

  # ---------------------------------------------------------------------------
  # Basic routing
  # ---------------------------------------------------------------------------

  def test_returns_false_for_non_network_robot
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)

    context = AIA::HandlerContext.new(robot: robot, prompt: "@Alice hello")
    refute @handler.handle(context)
  end

  def test_returns_false_when_no_mentions_in_prompt
    network = build_network("Alice", "Bob")
    context = AIA::HandlerContext.new(robot: network, prompt: "no mentions here")
    refute @handler.handle(context)
  end

  def test_returns_false_when_mentions_dont_match_any_robot
    network = build_network("Alice", "Bob")
    context = AIA::HandlerContext.new(robot: network, prompt: "@Charlie do something")

    @ui.stubs(:display_info)
    refute @handler.handle(context)
  end

  def test_returns_true_when_mention_matches_a_robot
    alice = build_mock_robot("Alice")
    network = mock_network([alice])

    @streaming_runner.stubs(:run).returns([OpenStruct.new(reply: "hello"), nil, 0.1])

    context = AIA::HandlerContext.new(robot: network, prompt: "@Alice hello")
    assert @handler.handle(context)
  end

  # ---------------------------------------------------------------------------
  # 5.4 — Mention stripping
  # ---------------------------------------------------------------------------

  def test_mention_is_stripped_from_prompt_sent_to_robot
    alice = build_mock_robot("Alice")
    network = mock_network([alice])

    captured_prompt = nil
    @streaming_runner.stubs(:run)
      .with { |*args| captured_prompt = args[1]; true }
      .returns([OpenStruct.new(reply: "hi"), nil, 0.05])

    @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@Alice please help me"))

    refute_includes captured_prompt, "@Alice",
      "The @mention should be stripped before sending to the robot"
    assert_includes captured_prompt, "please help me"
  end

  def test_multiple_mentions_are_stripped_from_prompt
    alice = build_mock_robot("Alice")
    bob   = build_mock_robot("Bob")
    network = mock_network([alice, bob])

    prompts_captured = []
    @streaming_runner.stubs(:run)
      .with { |*args| prompts_captured << args[1]; true }
      .returns([OpenStruct.new(reply: "ok"), nil, 0.05])

    @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@Alice @Bob what is 2+2?"))

    prompts_captured.each do |p|
      refute_includes p, "@Alice"
      refute_includes p, "@Bob"
      assert_includes p, "what is 2+2?"
    end
  end

  def test_case_insensitive_mention_stripped
    alice = build_mock_robot("Alice")
    network = mock_network([alice])

    captured = nil
    @streaming_runner.stubs(:run)
      .with { |*args| captured = args[1]; true }
      .returns([OpenStruct.new(reply: "response"), nil, 0.0])

    @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@alice summarize this"))

    refute_includes captured, "@alice"
    assert_includes captured, "summarize this"
  end

  private

  def build_mock_robot(name)
    r = mock(name.downcase)
    r.stubs(:name).returns(name)
    r.stubs(:model).returns("gpt-4o-mini")
    r
  end

  def build_network(*names)
    robots = names.map { |n| build_mock_robot(n) }
    mock_network(robots)
  end

  def mock_network(robot_list)
    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    robot_hash = robot_list.each_with_object({}) { |r, h| h[r.name.downcase.to_sym] = r }
    network.stubs(:robots).returns(robot_hash)
    network.robots.stubs(:values).returns(robot_list)
    network
  end
end
