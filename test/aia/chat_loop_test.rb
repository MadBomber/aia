# frozen_string_literal: true
# test/aia/chat_loop_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ChatLoopREPLTest < Minitest::Test
  # ===================================================================
  # Setup — build a ChatLoop with all sub-components mocked
  # ===================================================================

  def setup
    @robot = mock('robot')
    @robot.stubs(:is_a?).returns(false)
    @robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    @robot.stubs(:respond_to?).returns(false)
    @robot.stubs(:respond_to?).with(:memory).returns(false)
    @robot.stubs(:respond_to?).with(:local_tools).returns(false)
    @robot.stubs(:respond_to?).with(:mcp_tools).returns(false)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_chat_header)
    @ui.stubs(:display_chat_end)
    @ui.stubs(:load_chat_history)
    @ui.stubs(:display_response)
    @ui.stubs(:display_separator)

    @directive_processor = mock('directive_processor')
    @directive_processor.stubs(:directive?).returns(false)

    @streaming_runner = mock('streaming_runner')
    AIA::StreamingRunner.stubs(:new).returns(@streaming_runner)

    @mention_router = mock('mention_router')
    AIA::MentionRouter.stubs(:new).returns(@mention_router)
    @mention_router.stubs(:handle).returns(false)

    @special_mode_handler = mock('special_mode_handler')
    AIA::SpecialModeHandler.stubs(:new).returns(@special_mode_handler)
    @special_mode_handler.stubs(:handle).returns(false)

    @tool_filter_strategy = mock('tool_filter_strategy')
    AIA::ToolFilterStrategy.stubs(:new).returns(@tool_filter_strategy)
    @tool_filter_strategy.stubs(:resolve).returns(nil)
    @tool_filter_strategy.stubs(:active_strategy_label).returns("none")

    @model_switch_handler = mock('model_switch_handler')
    AIA::ModelSwitchHandler.stubs(:new).returns(@model_switch_handler)
    @model_switch_handler.stubs(:handle).returns(false)

    @config = OpenStruct.new(
      flags: OpenStruct.new(tokens: false, debug: false),
      output: OpenStruct.new(file: nil),
      context_files: [],
      models: [OpenStruct.new(name: 'gpt-4o-mini')]
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:debug?).returns(false)
    AIA.stubs(:speak?).returns(false)
    AIA.stubs(:turn_state).returns(AIA::TurnState.new)

    Signal.stubs(:trap)

    @chat_loop = AIA::ChatLoop.new(
      @robot, @ui, @directive_processor, filters: {}
    )
  end

  # ===================================================================
  # run_loop exit conditions
  # ===================================================================

  def test_run_loop_exits_on_empty_input
    @ui.stubs(:ask_question).returns("")
    @ui.expects(:display_chat_end).once
    @chat_loop.start
  end

  def test_run_loop_exits_on_nil_input
    @ui.stubs(:ask_question).returns(nil)
    @ui.expects(:display_chat_end).once
    @chat_loop.start
  end

  def test_run_loop_exits_on_exit_command
    @ui.stubs(:ask_question).returns("exit")
    @ui.expects(:display_chat_end).once
    @chat_loop.start
  end

  # ===================================================================
  # Directive handling
  # ===================================================================

  def test_unknown_directive_displays_info_message
    @ui.stubs(:ask_question).returns("/bogus_directive", "")
    @directive_processor.stubs(:directive?).with("/bogus_directive").returns(false)
    @ui.expects(:display_info).with(regexp_matches(/Unknown directive/)).once
    @chat_loop.start
  end

  def test_known_directive_nil_output_does_not_send_to_robot
    @ui.stubs(:ask_question).returns("/clear", "")
    @directive_processor.stubs(:directive?).with("/clear").returns(true)
    @directive_processor.stubs(:process).with("/clear", nil).returns(nil)
    @streaming_runner.expects(:run).never
    @chat_loop.start
  end

  def test_known_directive_with_output_sends_synthetic_prompt_to_robot
    result = mock('result')
    result.stubs(:respond_to?).returns(false)
    @ui.stubs(:ask_question).returns("/shell ls", "")
    @directive_processor.stubs(:directive?).with("/shell ls").returns(true)
    @directive_processor.stubs(:process).with("/shell ls", nil).returns("file1.rb\nfile2.rb")
    @streaming_runner.stubs(:run).returns([result, nil, 0.1])
    @chat_loop.stubs(:present_result)
    @streaming_runner.expects(:run).once
    @chat_loop.start
  end

  # ===================================================================
  # Normal prompt → tool filter strategy invoked
  # ===================================================================

  def test_normal_prompt_calls_tool_filter_strategy_resolve
    result = mock('result')
    result.stubs(:respond_to?).returns(false)
    result.stubs(:is_a?).returns(false)

    @ui.stubs(:ask_question).returns("what is Ruby?", "")
    pm_result = mock('pm_result')
    pm_result.stubs(:to_s).returns("what is Ruby?")
    PM.stubs(:parse_string).returns(pm_result)

    @streaming_runner.stubs(:run).returns([result, nil, 0.5])
    @chat_loop.stubs(:present_result)
    AIA.turn_state.stubs(:active_mcp_servers=)

    @tool_filter_strategy.expects(:resolve).with("what is Ruby?").returns(nil).once
    @chat_loop.start
  end

  def test_normal_prompt_calls_streaming_runner_with_resolved_tools
    result = mock('result')
    result.stubs(:respond_to?).returns(false)
    result.stubs(:is_a?).returns(false)

    @ui.stubs(:ask_question).returns("write a haiku", "")
    pm_result = mock('pm_result')
    pm_result.stubs(:to_s).returns("write a haiku")
    PM.stubs(:parse_string).returns(pm_result)

    @tool_filter_strategy.stubs(:resolve).returns(["tool_a"])
    @streaming_runner.expects(:run).with(@robot, "write a haiku", tools: ["tool_a"]).returns([result, nil, 0.3])
    @chat_loop.stubs(:present_result)
    AIA.turn_state.stubs(:active_mcp_servers=)

    @chat_loop.start
  end

  # ===================================================================
  # Model switch skips robot call
  # ===================================================================

  def test_model_switch_skips_streaming_runner
    AIA.stubs(:client).returns(@robot)
    @ui.stubs(:ask_question).returns("use gpt-4o", "")
    @model_switch_handler.stubs(:handle).returns(true)
    @special_mode_handler.stubs(:robot=)
    @streaming_runner.expects(:run).never
    @chat_loop.start
  end
end
