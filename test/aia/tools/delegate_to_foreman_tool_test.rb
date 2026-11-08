# frozen_string_literal: true

# test/aia/tools/delegate_to_foreman_tool_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'
require_relative '../../../lib/aia/tools/delegate_to_foreman_tool'

class DelegateToForemanToolTest < Minitest::Test
  def setup
    AIA::DelegateToForemanTool.reset!
    @model_spec = OpenStruct.new(name: 'gpt-4o-mini')
    AIA.stubs(:config).returns(OpenStruct.new(models: [@model_spec]))
  end

  def teardown
    AIA::DelegateToForemanTool.reset!
    AIA.unstub(:config)
  end

  def test_foreman_is_built_with_the_task_board_tool
    foreman = Object.new
    AIA::RobotFactory.stubs(:build_run_config).returns(:run_config)
    AIA::RobotFactory.expects(:build_robot)
                     .with(@model_spec, has_entries(name: 'Foreman', local_tools: [AIA::TaskBoardTool], config: :run_config))
                     .returns(foreman)

    assert_same foreman, AIA::DelegateToForemanTool.foreman
  end
end
