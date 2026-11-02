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
    robot.stubs(:network?).returns(false)

    context = AIA::HandlerContext.new(robot: robot, prompt: "@Alice hello")
    refute @handler.handle(context)
  end

  def test_returns_false_when_no_mentions_in_prompt
    network = build_network("Alice", "Bob")
    context = AIA::HandlerContext.new(robot: network, prompt: "no mentions here")
    refute @handler.handle(context)
  end

  def test_returns_true_and_reports_when_all_mentions_are_unknown
    network = build_network("Alice", "Bob")
    context = AIA::HandlerContext.new(robot: network, prompt: "@Charlie do something")

    @ui.expects(:display_info).with(regexp_matches(/Unknown robot.*Charlie/i))
    assert @handler.handle(context)
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
                     .with do |*args|
      captured_prompt = args[1]
      true
    end
      .returns([OpenStruct.new(reply: "hi"), nil, 0.05])

    @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@Alice please help me"))

    refute_includes captured_prompt, "@Alice",
                    "The @mention should be stripped before sending to the robot"
    assert_includes captured_prompt, "please help me"
  end

  def test_leading_mentions_run_concurrently_with_stripped_prompt
    # Leading address → concurrent path (FakeMember#run, in worker threads).
    alice = FakeMember.new("Alice")
    bob   = FakeMember.new("Bob")
    network = mock_network([alice, bob])

    @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@Alice @Bob what is 2+2?"))

    [alice, bob].each do |bot|
      p = bot.prompts.pop # only populated if the concurrent path ran this robot
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
                     .with do |*args|
      captured = args[1]
      true
    end
      .returns([OpenStruct.new(reply: "response"), nil, 0.0])

    @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@alice summarize this"))

    refute_includes captured, "@alice"
    assert_includes captured, "summarize this"
  end

  def test_body_mentions_run_sequentially_preserving_names
    # @names woven into the body → sequential path (streaming runner, one robot
    # at a time), and the @names survive in the message each robot receives.
    hemie = build_mock_robot("hemie")
    joker = build_mock_robot("joker")
    network = mock_network([hemie, joker])

    captured = []
    @streaming_runner.stubs(:run)
                     .with do |*args|
      captured << args[1]
      true
    end
                     .returns([OpenStruct.new(reply: "ok"), nil, 0.0])

    @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "hello @hemie have you met @joker"))

    assert_equal 2, captured.size, "both body-mentioned robots run via the sequential streaming path"
    captured.each do |p|
      assert_includes p, "@hemie"
      assert_includes p, "@joker"
      assert_includes p, "hello"
    end
  end

  def test_crew_token_broadcasts_concurrently_to_every_member
    alice = FakeMember.new("Alice")
    bob   = FakeMember.new("Bob")
    network = mock_network([alice, bob])

    handled = @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@crew status report"))

    assert handled
    refute alice.prompts.empty?, "Alice should have been broadcast to"
    refute bob.prompts.empty?, "Bob should have been broadcast to"
  end

  def test_crew_token_is_recognized_not_unknown
    alice = build_mock_robot("Alice")
    network = mock_network([alice])
    ran = false
    @streaming_runner.stubs(:run).with do |*_|
      ran = true
      true
    end
                                 .returns([OpenStruct.new(reply: "ok"), nil, 0.0])

    handled = @handler.handle(AIA::HandlerContext.new(robot: network, prompt: "@crew hello"))

    assert handled
    assert ran, "@crew should broadcast (run robots), not be treated as an unknown name"
  end

  def test_sequential_replies_are_shared_with_peer_robots
    alice = mock('Alice')
    alice.stubs(:name).returns("Alice")

    bob_chat = mock('bob_chat')
    bob = mock('Bob')
    bob.stubs(:name).returns("Bob")
    bob.stubs(:respond_to?).with(:chat).returns(true)
    bob.stubs(:chat).returns(bob_chat)

    carol_chat = mock('carol_chat')
    carol = mock('Carol')
    carol.stubs(:name).returns("Carol")
    carol.stubs(:respond_to?).with(:chat).returns(true)
    carol.stubs(:chat).returns(carol_chat)

    # Alice's reply lands in Bob's and Carol's history, but not Alice's own.
    bob_chat.expects(:add_message).with({ role: :user, content: "[Alice]: found the bug" })
    carol_chat.expects(:add_message).with({ role: :user, content: "[Alice]: found the bug" })

    @handler.send(:share_with_peers, [alice, bob, carol], alice, "found the bug")
  end

  private

  # A plain robot double for the concurrent broadcast path: its #run executes in
  # a worker thread, where Mocha's thread-local mockery wouldn't see stubs, so we
  # use a real object that records prompts to a thread-safe queue.
  class FakeMember
    attr_reader :name, :model, :prompts

    def initialize(name)
      @name    = name
      @model   = "gpt-4o-mini"
      @prompts = Queue.new
    end

    def run(prompt, **_opts)
      @prompts << prompt
      OpenStruct.new(reply: "ok from #{@name}")
    end
  end

  def build_mock_robot(name)
    r = mock(name.downcase)
    r.stubs(:name).returns(name)
    r.stubs(:model).returns("gpt-4o-mini")
    r.stubs(:respond_to?).with(:chat).returns(false) # no context-sharing in these doubles
    r
  end

  def build_network(*names)
    robots = names.map { |n| build_mock_robot(n) }
    mock_network(robots)
  end

  def mock_network(robot_list)
    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:network?).returns(true)
    robot_hash = robot_list.to_h { |r| [r.name.downcase.to_sym, r] }
    network.stubs(:robots).returns(robot_hash)
    network.robots.stubs(:values).returns(robot_list)
    network.stubs(:crew).returns(robot_hash.values)
    network
  end
end
