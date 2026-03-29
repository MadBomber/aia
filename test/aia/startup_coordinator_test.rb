# frozen_string_literal: true
# test/aia/startup_coordinator_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/startup_coordinator'

class StartupCoordinatorTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(
        chat: false, debug: false, verbose: false, no_mcp: true,
        track_pipeline: false, tokens: false, tool_filter_a: false,
        tool_filter_b: false, tool_filter_c: false, tool_filter_d: false,
        tool_filter_e: false
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
end
