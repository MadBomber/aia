# frozen_string_literal: true

# test/aia/history_transfer_test.rb

require_relative '../test_helper'

class HistoryTransferTest < Minitest::Test
  Message = Struct.new(:role, :content)
  Reply   = Struct.new(:reply)

  # A robot double: records every run and answers with a fixed reply.
  class FakeRobot
    attr_reader :runs
    attr_accessor :messages

    def initialize(messages = [], reply: "summary text")
      @messages = messages
      @reply    = reply
      @runs     = []
    end

    def run(prompt, **opts)
      @runs << [prompt, opts]
      Reply.new(@reply)
    end
  end

  # A network double exposing the RobotLab::Runnable crew/chief interface.
  class FakeNetwork
    attr_reader :crew

    def initialize(*robots) = @crew = robots
    def chief = @crew.first
  end

  NO_TOOLS = { mcp: :none, tools: :none }.freeze

  def msg(role, content) = Message.new(role, content)

  # ---------------------------------------------------------------------------
  # mode_for
  # ---------------------------------------------------------------------------

  def test_mode_for_defaults_to_summarize_when_unset
    assert_equal :summarize, AIA::HistoryTransfer.mode_for(OpenStruct.new(model_switch_history: nil))
  end

  def test_mode_for_defaults_to_summarize_without_config
    assert_equal :summarize, AIA::HistoryTransfer.mode_for(nil)
  end

  def test_mode_for_reads_configured_mode
    assert_equal :clean,  AIA::HistoryTransfer.mode_for(OpenStruct.new(model_switch_history: "clean"))
    assert_equal :replay, AIA::HistoryTransfer.mode_for(OpenStruct.new(model_switch_history: " Replay "))
  end

  def test_mode_for_falls_back_on_unknown_mode
    assert_equal :summarize, AIA::HistoryTransfer.mode_for(OpenStruct.new(model_switch_history: "bogus"))
  end

  # ---------------------------------------------------------------------------
  # conversation / recipients
  # ---------------------------------------------------------------------------

  def test_conversation_keeps_only_non_empty_user_and_assistant_turns
    robot = FakeRobot.new([msg(:system, "sys"), msg(:user, "hi"), msg(:tool, "x"),
                           msg(:assistant, "  "), msg(:assistant, "hello")])

    assert_equal %w[hi hello], AIA::HistoryTransfer.conversation(robot).map(&:content)
  end

  def test_conversation_reads_the_network_chief
    chief = FakeRobot.new([msg(:user, "from chief")])
    other = FakeRobot.new([msg(:user, "from other")])

    assert_equal ["from chief"], AIA::HistoryTransfer.conversation(FakeNetwork.new(chief, other)).map(&:content)
  end

  def test_conversation_empty_without_messages
    assert_empty AIA::HistoryTransfer.conversation(Object.new)
    assert_empty AIA::HistoryTransfer.conversation(nil)
  end

  def test_recipients_is_the_crew_for_a_network
    a = FakeRobot.new
    b = FakeRobot.new

    assert_equal [a, b], AIA::HistoryTransfer.recipients(FakeNetwork.new(a, b))
  end

  def test_recipients_is_the_robot_itself
    robot = FakeRobot.new

    assert_equal [robot], AIA::HistoryTransfer.recipients(robot)
  end

  # ---------------------------------------------------------------------------
  # replay_history
  # ---------------------------------------------------------------------------

  def test_replay_history_replays_user_turns_in_order
    old = FakeRobot.new([msg(:user, "first"), msg(:assistant, "reply"), msg(:user, "second")])
    new_robot = FakeRobot.new

    AIA::HistoryTransfer.replay_history(old, new_robot)

    assert_equal [["first", NO_TOOLS], ["second", NO_TOOLS]], new_robot.runs
  end

  def test_replay_history_replays_to_every_crew_member
    old = FakeNetwork.new(FakeRobot.new([msg(:user, "hello")]))
    a = FakeRobot.new
    b = FakeRobot.new

    AIA::HistoryTransfer.replay_history(old, FakeNetwork.new(a, b))

    assert_equal [["hello", NO_TOOLS]], a.runs
    assert_equal [["hello", NO_TOOLS]], b.runs
  end

  def test_replay_history_noop_without_history
    new_robot = FakeRobot.new

    AIA::HistoryTransfer.replay_history(FakeRobot.new, new_robot)
    AIA::HistoryTransfer.replay_history(Object.new, new_robot)

    assert_empty new_robot.runs
  end

  def test_replay_history_warns_instead_of_raising
    old = FakeRobot.new([msg(:user, "hi")])
    broken = FakeRobot.new
    def broken.run(*, **) = raise(StandardError, "something broke")

    _, err = capture_io { AIA::HistoryTransfer.replay_history(old, broken) }

    assert_includes err, "Warning: History replay failed: something broke"
  end

  # ---------------------------------------------------------------------------
  # summarize_history
  # ---------------------------------------------------------------------------

  def test_summarize_history_asks_the_old_chief_for_a_summary
    old = FakeRobot.new([msg(:user, "user turn"), msg(:assistant, "assistant reply")])

    AIA::HistoryTransfer.summarize_history(old, FakeRobot.new)

    prompt, opts = old.runs.first
    assert_match(/Summarize this conversation/, prompt)
    assert_match(/user: user turn/, prompt)
    assert_match(/assistant: assistant reply/, prompt)
    assert_equal NO_TOOLS, opts
  end

  def test_summarize_history_injects_the_summary_into_every_crew_member
    old = FakeNetwork.new(FakeRobot.new([msg(:user, "hi")], reply: "the gist"))
    a = FakeRobot.new
    b = FakeRobot.new

    AIA::HistoryTransfer.summarize_history(old, FakeNetwork.new(a, b))

    expected = [["Context from previous conversation: the gist", NO_TOOLS]]
    assert_equal expected, a.runs
    assert_equal expected, b.runs
  end

  def test_summarize_history_uses_to_s_when_summary_lacks_reply
    old = FakeRobot.new([msg(:user, "hi")])
    def old.run(*, **) = "plain string"
    new_robot = FakeRobot.new

    AIA::HistoryTransfer.summarize_history(old, new_robot)

    assert_equal "Context from previous conversation: plain string", new_robot.runs.first.first
  end

  def test_summarize_history_noop_without_history
    old = FakeRobot.new([msg(:system, "sys only")])
    new_robot = FakeRobot.new

    AIA::HistoryTransfer.summarize_history(old, new_robot)
    AIA::HistoryTransfer.summarize_history(Object.new, new_robot)

    assert_empty old.runs
    assert_empty new_robot.runs
  end

  def test_summarize_history_warns_instead_of_raising
    old = FakeRobot.new([msg(:user, "hi")])
    def old.run(*, **) = raise(StandardError, "summarize broke")

    _, err = capture_io { AIA::HistoryTransfer.summarize_history(old, FakeRobot.new) }

    assert_includes err, "Warning: History summarization failed: summarize broke"
  end
end
