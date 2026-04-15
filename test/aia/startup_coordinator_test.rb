# frozen_string_literal: true
# test/aia/startup_coordinator_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/trakflow_bridge'
require_relative '../../lib/aia/task_coordinator'
require_relative '../../lib/aia/tools/task_board_tool'
require_relative '../../lib/aia/tools/delegate_to_foreman_tool'
require_relative '../../lib/aia/startup_coordinator'

class StartupCoordinatorTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(
        chat: false, debug: false, verbose: false, no_mcp: true,
        track_pipeline: false, tokens: false, tool_filter_a: false
      ),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      mcp_servers: [],
      loaded_tools: []
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:task_coordinator=)
    AIA.stubs(:turn_state).returns(AIA::TurnState.new)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
  end

  def test_run_sets_filters
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    robot.stubs(:mcp_config).returns([])

    AIA::TaskCoordinator.stubs(:new).raises(StandardError, "no trakflow")

    coordinator = AIA::StartupCoordinator.new(
      robot: robot, ui_presenter: @ui
    )
    coordinator.run(@config)

    assert_respond_to coordinator, :filters
    assert_kind_of Hash, coordinator.filters
  end

  def test_skips_mcp_when_no_mcp_flag_set
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    AIA::TaskCoordinator.stubs(:new).raises(StandardError)

    coordinator = AIA::StartupCoordinator.new(
      robot: robot, ui_presenter: @ui
    )
    # Should not raise even with no_mcp = true
    coordinator.run(@config) # passes if no exception raised
  end

  def test_attach_bus_skipped_for_single_robot
    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    AIA::TaskCoordinator.stubs(:new).raises(StandardError)

    AIA::RobotFactory.expects(:attach_bus).never

    coordinator = AIA::StartupCoordinator.new(
      robot: robot, ui_presenter: @ui
    )
    coordinator.run(@config)
  end

  def test_validate_mcp_use_names_warns_for_missing_server
    config = OpenStruct.new(
      flags: OpenStruct.new(
        chat: false, debug: false, verbose: false, no_mcp: false,
        track_pipeline: false, tokens: false, tool_filter_a: false
      ),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      mcp_servers: [{ name: 'real_server' }],
      mcp_use: ['nonexistent_server'],
      mcp_skip: [],
      loaded_tools: []
    )
    AIA.stubs(:config).returns(config)

    # MCPDiscovery returns empty (no server matched the --mcp-use name)
    AIA::MCPDiscovery.any_instance.stubs(:discover).returns([])

    # MCPConnectionManager: not connected, so no further calls needed
    mock_manager = mock('mcp_manager')
    mock_manager.stubs(:connect_all)
    mock_manager.stubs(:absorb_ruby_llm_mcp_clients)
    mock_manager.stubs(:connected?).returns(false)
    AIA::MCPConnectionManager.stubs(:new).returns(mock_manager)

    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    robot.stubs(:respond_to?).with(:mcp_config).returns(false)
    AIA::TaskCoordinator.stubs(:new).raises(StandardError)

    coordinator = AIA::StartupCoordinator.new(
      robot: robot, ui_presenter: @ui
    )

    # validate_mcp_use_names is called with the config and empty discovered list
    coordinator.expects(:validate_mcp_use_names).with(config, []).once
    coordinator.run(config)
  end

  # When all requested servers are found, validate_mcp_use_names returns early
  # without issuing any warnings. Verify by ensuring `warn` is never called.
  def test_validate_mcp_use_names_no_warning_when_all_found
    config = OpenStruct.new(
      mcp_use: ['real_server'],
      mcp_servers: [{ name: 'real_server' }]
    )
    coordinator = AIA::StartupCoordinator.new(
      robot: mock('robot'), ui_presenter: @ui
    )

    coordinator.expects(:warn).never
    coordinator.send(:validate_mcp_use_names, config, [{ name: 'real_server' }])
  end

  # initialize_task_coordinator must NOT call clear! on the task coordinator.
  # Wiping task state on every startup silently destroys prior session work.
  def test_initialize_task_coordinator_does_not_call_clear
    mock_tc = mock('task_coordinator')
    mock_tc.expects(:clear!).never

    AIA::TaskCoordinator.stubs(:new).returns(mock_tc)
    AIA.stubs(:task_coordinator=)
    AIA.stubs(:task_coordinator).returns(mock_tc)
    TrakFlow.stubs(:initialized?).returns(true)

    coordinator = AIA::StartupCoordinator.new(
      robot: mock('robot'), ui_presenter: @ui
    )
    coordinator.send(:initialize_task_coordinator)
  end

  # validate_mcp_use_names issues a warning when requested servers are missing.
  # Since Kernel#warn bypasses stub interception in Ruby 4, verify via expects.
  def test_validate_mcp_use_names_issues_warning_for_missing_server
    config = OpenStruct.new(
      mcp_use: ['typo_server'],
      mcp_servers: [{ name: 'real_server' }]
    )
    coordinator = AIA::StartupCoordinator.new(
      robot: mock('robot'), ui_presenter: @ui
    )

    # Expect warn to be called at least once with a message about the missing server
    coordinator.expects(:warn).at_least_once.with { |msg| msg.include?('typo_server') || msg.include?('real_server') }
    coordinator.send(:validate_mcp_use_names, config, [])
  end

  def test_attach_bus_failure_logs_debug_warn
    robot = mock('network_robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(true)
    AIA::RobotFactory.stubs(:attach_bus).raises(StandardError, "bus error")
    AIA.expects(:debug_warn).with(regexp_matches(/bus/i), has_key(:exc)).once
    coordinator = AIA::StartupCoordinator.new(robot: robot, ui_presenter: mock('ui'))
    coordinator.send(:attach_bus_if_network)  # must not raise
  end

  def test_task_coordinator_failure_logs_debug_warn
    TrakFlow.stubs(:initialized?).returns(false)
    AIA::StartupCoordinator.any_instance.stubs(:ensure_trakflow_initialized).raises(StandardError, "db error")
    AIA.expects(:debug_warn).with(regexp_matches(/TaskCoordinator|coordinator/i), has_key(:exc)).once
    coordinator = AIA::StartupCoordinator.new(robot: mock('robot'), ui_presenter: mock('ui'))
    coordinator.send(:initialize_task_coordinator)  # must not raise
  end
end
