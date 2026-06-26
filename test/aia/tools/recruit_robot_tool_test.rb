# frozen_string_literal: true

# test/aia/tools/recruit_robot_tool_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'

class RecruitRobotToolTest < Minitest::Test
  def setup
    @tool = AIA::RecruitRobotTool.new
  end

  def test_recruits_with_explicit_provider_model_and_prompt
    robot = stub_robot('researcher', 'ollama/qwen3.6:latest')
    AIA::Crew.expects(:recruit).with({
      name: 'researcher', model: 'qwen3.6:latest', provider: 'ollama',
      system_prompt: 'You are careful'
    }).returns(robot)

    out = @tool.execute(
      name: 'researcher', model: 'ollama/qwen3.6:latest', system_prompt: 'You are careful'
    )

    assert_match(/Recruited 'researcher'/, out)
    assert_match(/@researcher/, out)
  end

  def test_omitting_model_inherits_the_chiefs_model
    robot = stub_robot('helper', nil)
    AIA::Crew.expects(:recruit).with({
      name: 'helper', model: nil, provider: nil, system_prompt: nil
    }).returns(robot)

    out = @tool.execute(name: 'helper')

    assert_match(/Recruited 'helper'/, out)
  end

  def test_dash_model_inherits_and_blank_prompt_becomes_nil
    robot = stub_robot('helper', nil)
    AIA::Crew.expects(:recruit).with({
      name: 'helper', model: nil, provider: nil, system_prompt: nil
    }).returns(robot)

    @tool.execute(name: 'helper', model: '-', system_prompt: '   ')
  end

  def test_crew_error_is_returned_as_text
    AIA::Crew.stubs(:recruit).raises(AIA::CrewError, 'name taken')

    out = @tool.execute(name: 'joker')

    assert_match(/Could not recruit 'joker': name taken/, out)
  end

  private

  def stub_robot(name, model)
    robot = mock(name)
    robot.stubs(:name).returns(name)
    robot.stubs(:model).returns(model)
    robot
  end
end
