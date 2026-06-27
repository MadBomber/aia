# frozen_string_literal: true

# test/aia/tools/reskill_robot_tool_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'

class ReskillRobotToolTest < Minitest::Test
  def setup
    @tool = AIA::ReskillRobotTool.new
  end

  def test_reskills_with_split_skills_and_prompt
    robot = stub_robot('larry')
    AIA::Crew.expects(:reskill).with(
      'larry', skills: %w[testing performance], system_prompt: 'be terse'
    ).returns(robot)

    out = @tool.execute(name: 'larry', skills: 'testing, performance', system_prompt: 'be terse')

    assert_match(/Reset 'larry'/, out)
    assert_match(/@larry/, out)
  end

  def test_no_skills_and_blank_prompt_normalize
    robot = stub_robot('moe')
    AIA::Crew.expects(:reskill).with('moe', skills: [], system_prompt: nil).returns(robot)

    @tool.execute(name: 'moe', system_prompt: '   ')
  end

  def test_crew_error_is_returned_as_text
    AIA::Crew.stubs(:reskill).raises(AIA::CrewError, 'Cannot reskill the chief')

    out = @tool.execute(name: 'Tobor')

    assert_match(/Could not reskill 'Tobor': Cannot reskill the chief/, out)
  end

  private

  def stub_robot(name)
    robot = mock(name)
    robot.stubs(:name).returns(name)
    robot
  end
end
