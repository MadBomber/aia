# frozen_string_literal: true

# test/aia/decision_applier_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class DecisionApplierTest < Minitest::Test
  def setup
    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_warning)
    @ui.stubs(:display_error)

    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      mcp_servers: [],
      flags: OpenStruct.new(verbose: false)
    )

    AIA.stubs(:config).returns(@config)
    AIA.stubs(:turn_state).returns(AIA::TurnState.new)
    AIA.stubs(:session_tracker).returns(nil)

    @applier = AIA::DecisionApplier.new(@ui)
  end

  def teardown
    super
  end

  # =========================================================================
  # Empty decisions — no-op
  # =========================================================================

  def test_apply_with_empty_decisions_is_noop
    decisions = AIA::Decisions.new

    applied = @applier.apply(decisions, @config)

    refute applied.model_overridden
    assert_nil applied.temp_robot
    refute applied.mcp_filtered
    refute applied.tool_filtered
    assert_equal 0, applied.warnings_shown
    refute applied.blocked
  end

  # =========================================================================
  # Gate warnings — visible without --verbose
  # =========================================================================

  def test_gate_warn_shows_warning_via_ui
    decisions = AIA::Decisions.new
    decisions.add(:gate, action: "warn", message: "Session cost is over $5.")

    @ui.expects(:display_warning).with("Session cost is over $5.").once

    applied = @applier.apply(decisions, @config)

    assert_equal 1, applied.warnings_shown
    refute applied.blocked
  end

  def test_multiple_gate_warnings_all_shown
    decisions = AIA::Decisions.new
    decisions.add(:gate, action: "warn", message: "Warning 1")
    decisions.add(:gate, action: "warn", message: "Warning 2")

    @ui.expects(:display_warning).with("Warning 1").once
    @ui.expects(:display_warning).with("Warning 2").once

    applied = @applier.apply(decisions, @config)

    assert_equal 2, applied.warnings_shown
  end

  def test_gate_block_stops_the_turn
    decisions = AIA::Decisions.new
    decisions.add(:gate, action: "block", message: "Blocked for safety")

    @ui.expects(:display_error).with("Blocked: Blocked for safety").once

    applied = @applier.apply(decisions, @config)

    assert applied.blocked
  end

  def test_gate_block_skips_model_and_mcp_decisions
    decisions = AIA::Decisions.new
    decisions.add(:gate, action: "block", message: "Blocked")
    decisions.add(:model_decision, model: "gpt-4o", reason: "should not fire")
    decisions.add(:mcp_activate, server: "github", reason: "should not fire")

    applied = @applier.apply(decisions, @config)

    assert applied.blocked
    refute applied.model_overridden
    refute applied.mcp_filtered
  end

  # =========================================================================
  # Model decisions — per-turn override
  # =========================================================================

  def test_model_decision_builds_temp_robot_for_different_model
    decisions = AIA::Decisions.new
    decisions.add(:model_decision, model: "claude-sonnet-4-20250514", reason: "complex query")

    # Stub AIA.client for the temp robot builder
    primary = mock('primary_robot')
    primary.stubs(:respond_to?).with(:mcp_tools).returns(false)
    AIA.stubs(:client).returns(primary)

    # Stub RobotFactory methods used by build_temp_robot
    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).returns("You are helpful.")
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:build_run_config).returns(nil)

    fake_robot = mock('temp_robot')
    RobotLab.stubs(:build).returns(fake_robot)

    @ui.expects(:display_info).with(includes("[KBS] Using claude-sonnet-4-20250514")).once

    applied = @applier.apply(decisions, @config)

    assert applied.model_overridden
    assert_equal fake_robot, applied.temp_robot
  end

  def test_model_decision_skipped_when_same_as_current
    decisions = AIA::Decisions.new
    decisions.add(:model_decision, model: "gpt-4o-mini", reason: "same model")

    applied = @applier.apply(decisions, @config)

    refute applied.model_overridden
    assert_nil applied.temp_robot
  end

  def test_model_decision_at_startup_modifies_config_permanently
    decisions = AIA::Decisions.new
    decisions.add(:model_decision, model: "claude-sonnet-4-20250514", reason: "vision needed")

    @ui.expects(:display_info).with(includes("[KBS] Startup model")).once

    applied = @applier.apply(decisions, @config, startup: true)

    assert applied.model_overridden
    assert_nil applied.temp_robot  # No temp robot at startup
    assert_equal "claude-sonnet-4-20250514", @config.models.first.name
  end

  def test_model_decision_at_startup_skipped_when_same
    decisions = AIA::Decisions.new
    decisions.add(:model_decision, model: "gpt-4o-mini", reason: "same model")

    applied = @applier.apply(decisions, @config, startup: true)

    refute applied.model_overridden
    assert_equal "gpt-4o-mini", @config.models.first.name
  end

  # =========================================================================
  # MCP filtering
  # =========================================================================

  def test_mcp_activation_sets_turn_state
    turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(turn_state)

    decisions = AIA::Decisions.new
    decisions.add(:mcp_activate, server: "github", reason: "code domain")
    decisions.add(:mcp_activate, server: "filesystem", reason: "code domain")

    applied = @applier.apply(decisions, @config)

    assert applied.mcp_filtered
    assert_equal %w[github filesystem], turn_state.active_mcp_servers
  end

  def test_empty_mcp_activations_does_not_set_turn_state
    turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(turn_state)

    decisions = AIA::Decisions.new

    applied = @applier.apply(decisions, @config)

    refute applied.mcp_filtered
    assert_nil turn_state.active_mcp_servers
  end

  # =========================================================================
  # Tool filtering
  # =========================================================================

  def test_tool_activation_sets_turn_state
    turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(turn_state)

    decisions = AIA::Decisions.new
    decisions.add(:tool_activate, tool: "word_count", reason: "text domain")
    decisions.add(:tool_activate, tool: "search_files", reason: "code domain")

    @ui.expects(:display_info).with(includes("[KBS] Tools for this turn")).once

    applied = @applier.apply(decisions, @config)

    assert applied.tool_filtered
    assert_equal %w[word_count search_files], turn_state.active_tools
  end

  def test_empty_tool_activations_does_not_set_turn_state
    turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(turn_state)

    decisions = AIA::Decisions.new

    applied = @applier.apply(decisions, @config)

    refute applied.tool_filtered
    assert_nil turn_state.active_tools
  end

  # =========================================================================
  # Learning signals
  # =========================================================================

  def test_learning_dissatisfaction_records_model_switch
    tracker = mock('session_tracker')
    tracker.expects(:record_model_switch).with(
      from: "gpt-4o-mini",
      to: "unknown",
      reason: "kbs_dissatisfaction"
    ).once
    AIA.stubs(:session_tracker).returns(tracker)

    decisions = AIA::Decisions.new
    decisions.add(:learning, signal: "model_dissatisfaction", model: "gpt-4o-mini")

    @applier.apply(decisions, @config)
  end

  def test_learning_success_records_user_feedback
    tracker = mock('session_tracker')
    tracker.expects(:record_user_feedback).with(satisfied: true).once
    AIA.stubs(:session_tracker).returns(tracker)

    decisions = AIA::Decisions.new
    decisions.add(:learning, signal: "model_success", model: "gpt-4o-mini")

    @applier.apply(decisions, @config)
  end

  def test_learning_signals_skipped_when_no_tracker
    AIA.stubs(:session_tracker).returns(nil)

    decisions = AIA::Decisions.new
    decisions.add(:learning, signal: "model_dissatisfaction", model: "gpt-4o-mini")

    # Should not raise
    @applier.apply(decisions, @config)
  end

  def test_learning_cost_update_logs_to_logger
    tracker = mock('session_tracker')
    AIA.stubs(:session_tracker).returns(tracker)

    mock_logger = mock('logger')
    mock_logger.expects(:info).with(includes("cost_update total=5.23")).once
    AIA::LoggerManager.stubs(:aia_logger).returns(mock_logger)

    decisions = AIA::Decisions.new
    decisions.add(:learning, signal: "cost_update", total: 5.23)

    @applier.apply(decisions, @config)
  end

  # =========================================================================
  # Temp robot inherits MCP tools
  # =========================================================================

  def test_temp_robot_inherits_mcp_tools_from_primary
    decisions = AIA::Decisions.new
    decisions.add(:model_decision, model: "claude-sonnet-4-20250514", reason: "complex")

    mcp_tool = mock('mcp_tool')
    primary = mock('primary_robot')
    primary.stubs(:respond_to?).with(:mcp_tools).returns(true)
    primary.stubs(:mcp_tools).returns([mcp_tool])
    AIA.stubs(:client).returns(primary)

    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).returns("prompt")
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:build_run_config).returns(nil)

    fake_robot = mock('temp_robot')
    fake_robot.stubs(:respond_to?).with(:mcp_tools=).returns(true)
    fake_robot.expects(:mcp_tools=).with([mcp_tool]).once
    RobotLab.stubs(:build).returns(fake_robot)

    applied = @applier.apply(decisions, @config)

    assert applied.model_overridden
  end

  # =========================================================================
  # Temp robot build failure is graceful
  # =========================================================================

  def test_temp_robot_build_failure_returns_nil_robot
    decisions = AIA::Decisions.new
    decisions.add(:model_decision, model: "nonexistent-model", reason: "test")

    primary = mock('primary_robot')
    primary.stubs(:respond_to?).with(:mcp_tools).returns(false)
    AIA.stubs(:client).returns(primary)

    AIA::SystemPromptAssembler.stubs(:resolve_system_prompt).returns("prompt")
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:build_run_config).returns(nil)
    RobotLab.stubs(:build).raises(StandardError, "model not found")

    mock_logger = mock('logger')
    mock_logger.stubs(:warn)
    AIA::LoggerManager.stubs(:aia_logger).returns(mock_logger)

    applied = @applier.apply(decisions, @config)

    # model_overridden is false because temp_robot is nil
    refute applied.model_overridden
    assert_nil applied.temp_robot
  end
end
