# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/aia'

class CrewTest < Minitest::Test
  def setup
    @chief = stub_robot('Tobor')
    @crew  = mock('crew') # the Network behind AIA.client
    @crew.stubs(:chief).returns(@chief)
    @crew.stubs(:crew).returns([@chief])
    @crew.stubs(:respond_to?).with(:add_robot).returns(true)
    AIA.stubs(:client).returns(@crew)
  end

  def test_recruit_spawns_from_chief_with_model_and_adds_to_crew
    joker = stub_robot('joker')
    @chief.expects(:spawn).with(
      name: 'joker', system_prompt: 'You are funny',
      model: 'qwen3.6:latest', provider: 'ollama'
    ).returns(joker)
    @crew.expects(:add_robot).with(joker)

    result = AIA::Crew.recruit(
      name: 'joker', model: 'qwen3.6:latest', provider: 'ollama', system_prompt: 'You are funny'
    )

    assert_equal joker, result
  end

  def test_recruit_inherits_model_and_defaults_prompt_when_absent
    helper = stub_robot('helper')
    @chief.expects(:spawn).with(name: 'helper', system_prompt: 'You are helper.').returns(helper)
    @crew.expects(:add_robot).with(helper)

    AIA::Crew.recruit(name: 'helper')
  end

  def test_recruit_rejects_duplicate_name
    @crew.stubs(:crew).returns([@chief, stub_robot('joker')])

    error = assert_raises(AIA::CrewError) { AIA::Crew.recruit(name: 'joker') }
    assert_match(/already exists/, error.message)
  end

  def test_recruit_requires_a_crew
    AIA.stubs(:client).returns(Object.new) # no #add_robot

    error = assert_raises(AIA::CrewError) { AIA::Crew.recruit(name: 'x') }
    assert_match(/not a crew/, error.message)
  end

  def test_drop_removes_member
    @crew.stubs(:crew).returns([@chief, stub_robot('joker')])
    @crew.expects(:remove_robot).with('joker').returns(stub_robot('joker'))

    AIA::Crew.drop('joker')
  end

  def test_drop_rejects_the_chief
    error = assert_raises(AIA::CrewError) { AIA::Crew.drop('Tobor') }
    assert_match(/chief/, error.message)
  end

  def test_drop_rejects_unknown_member
    error = assert_raises(AIA::CrewError) { AIA::Crew.drop('ghost') }
    assert_match(/No crewmate/, error.message)
  end

  private

  def stub_robot(name)
    robot = mock(name)
    robot.stubs(:name).returns(name)
    robot
  end
end
