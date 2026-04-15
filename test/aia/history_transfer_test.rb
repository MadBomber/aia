# frozen_string_literal: true
# test/aia/history_transfer_test.rb

require_relative '../test_helper'

class HistoryTransferTest < Minitest::Test
  include AIA::HistoryTransfer

  def setup
    @old_robot = mock('old_robot')
    @new_robot = mock('new_robot')
  end

  def teardown
    Mocha::Mockery.instance.teardown
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def make_message(role, content)
    msg = mock("msg_#{role}")
    msg.stubs(:respond_to?).with(:role).returns(true)
    msg.stubs(:respond_to?).with(:content).returns(true)
    msg.stubs(:role).returns(role)
    msg.stubs(:content).returns(content)
    msg
  end

  # ---------------------------------------------------------------------------
  # replay_history — basic routing
  # ---------------------------------------------------------------------------

  def test_replay_history_replays_only_user_messages
    user_msg      = make_message(:user,      "hello from user")
    assistant_msg = make_message(:assistant, "reply from bot")

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([user_msg, assistant_msg])

    @new_robot.expects(:run).once.with("hello from user", mcp: :none, tools: :none)

    AIA::HistoryTransfer.replay_history(@old_robot, @new_robot)
  end

  def test_replay_history_noop_when_messages_empty
    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([])

    @new_robot.expects(:run).never

    AIA::HistoryTransfer.replay_history(@old_robot, @new_robot)
  end

  def test_replay_history_noop_when_old_robot_lacks_messages
    @old_robot.stubs(:respond_to?).with(:messages).returns(false)

    @new_robot.expects(:run).never

    AIA::HistoryTransfer.replay_history(@old_robot, @new_robot)
  end

  def test_replay_history_passes_correct_mcp_and_tools_options
    user_msg = make_message(:user, "test content")

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([user_msg])

    @new_robot.expects(:run).with("test content", mcp: :none, tools: :none)

    AIA::HistoryTransfer.replay_history(@old_robot, @new_robot)
  end

  def test_replay_history_handles_standard_error_gracefully
    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).raises(StandardError, "something broke")

    # Should not raise — rescue block emits a warn and returns normally
    assert_silent do
      AIA::HistoryTransfer.replay_history(@old_robot, @new_robot)
    end
  end

  def test_replay_history_skips_messages_without_role_method
    no_role_msg = mock('no_role_msg')
    no_role_msg.stubs(:respond_to?).with(:role).returns(false)

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([no_role_msg])

    @new_robot.expects(:run).never

    AIA::HistoryTransfer.replay_history(@old_robot, @new_robot)
  end

  def test_replay_history_replays_multiple_user_messages
    msg1 = make_message(:user, "first")
    msg2 = make_message(:user, "second")

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([msg1, msg2])

    @new_robot.expects(:run).with("first",  mcp: :none, tools: :none)
    @new_robot.expects(:run).with("second", mcp: :none, tools: :none)

    AIA::HistoryTransfer.replay_history(@old_robot, @new_robot)
  end

  # ---------------------------------------------------------------------------
  # summarize_history — basic routing
  # ---------------------------------------------------------------------------

  def test_summarize_history_noop_when_old_robot_has_no_messages
    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([])

    @new_robot.expects(:run).never

    AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)
  end

  def test_summarize_history_noop_when_old_robot_lacks_messages_method
    @old_robot.stubs(:respond_to?).with(:messages).returns(false)

    @new_robot.expects(:run).never

    AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)
  end

  def test_summarize_history_calls_old_robot_run_for_summary
    msg = make_message(:user, "hello")

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([msg])

    summary_result = mock('summary_result')
    summary_result.stubs(:respond_to?).with(:reply).returns(true)
    summary_result.stubs(:reply).returns("summary text")

    @old_robot.expects(:run).with(
      regexp_matches(/Summarize this conversation/),
      mcp: :none,
      tools: :none
    ).returns(summary_result)

    @new_robot.expects(:run).with(
      regexp_matches(/Context from previous conversation/),
      mcp: :none,
      tools: :none
    )

    AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)
  end

  def test_summarize_history_uses_reply_when_summary_responds_to_reply
    msg = make_message(:user, "hello")

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([msg])

    summary_result = mock('summary_result')
    summary_result.stubs(:respond_to?).with(:reply).returns(true)
    summary_result.stubs(:reply).returns("reply method result")

    @old_robot.expects(:run).returns(summary_result)
    @new_robot.expects(:run).with(
      "Context from previous conversation: reply method result",
      mcp: :none,
      tools: :none
    )

    AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)
  end

  def test_summarize_history_uses_to_s_when_summary_lacks_reply
    msg = make_message(:user, "hello")

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([msg])

    summary_result = mock('summary_result')
    summary_result.stubs(:respond_to?).with(:reply).returns(false)
    summary_result.stubs(:to_s).returns("to_s result")

    @old_robot.expects(:run).returns(summary_result)
    @new_robot.expects(:run).with(
      "Context from previous conversation: to_s result",
      mcp: :none,
      tools: :none
    )

    AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)
  end

  def test_summarize_history_handles_standard_error_gracefully
    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).raises(StandardError, "summarize broke")

    # Should not raise — rescue block emits a warn and returns normally
    assert_silent do
      AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)
    end
  end

  def test_summarize_history_includes_all_messages_in_prompt
    msg1 = make_message(:user,      "user turn 1")
    msg2 = make_message(:assistant, "assistant reply")
    msg3 = make_message(:user,      "user turn 2")

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([msg1, msg2, msg3])

    captured_prompt = nil
    summary_result = mock('summary_result')
    summary_result.stubs(:respond_to?).with(:reply).returns(true)
    summary_result.stubs(:reply).returns("ok")

    @old_robot.expects(:run).with do |prompt, **_opts|
      captured_prompt = prompt
      true
    end.returns(summary_result)

    @new_robot.stubs(:run)

    AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)

    assert_match(/user turn 1/,      captured_prompt)
    assert_match(/assistant reply/,  captured_prompt)
    assert_match(/user turn 2/,      captured_prompt)
  end

  def test_summarize_history_noop_when_all_messages_lack_role_method
    no_role_msg = mock('no_role_msg')
    no_role_msg.stubs(:respond_to?).with(:role).returns(false)

    @old_robot.stubs(:respond_to?).with(:messages).returns(true)
    @old_robot.stubs(:messages).returns([no_role_msg])

    @old_robot.expects(:run).never
    @new_robot.expects(:run).never

    AIA::HistoryTransfer.summarize_history(@old_robot, @new_robot)
  end
end
