# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/aia'

class CrewTest < Minitest::Test
  def setup
    @chief = stub_robot('Tobor')
    # The chief exposes its tools/MCP so recruits can inherit them.
    @chief.stubs(:respond_to?).with(:local_tools).returns(true)
    @chief.stubs(:local_tools).returns([])
    @chief.stubs(:respond_to?).with(:mcp_clients).returns(true)
    @chief.stubs(:mcp_clients).returns({})

    @crew  = mock('crew') # the Network behind AIA.client
    @crew.stubs(:chief).returns(@chief)
    @crew.stubs(:crew).returns([@chief])
    @crew.stubs(:respond_to?).with(:add_robot).returns(true)
    AIA.stubs(:client).returns(@crew)
  end

  def test_recruit_spawns_from_chief_with_model_and_adds_to_crew
    joker = stub_robot('joker')
    @chief.expects(:spawn).with(
      name: 'joker', system_prompt: 'You are funny', local_tools: [],
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
    @chief.expects(:spawn).with(name: 'helper', system_prompt: 'You are helper.', local_tools: []).returns(helper)
    @crew.expects(:add_robot).with(helper)

    AIA::Crew.recruit(name: 'helper')
  end

  def test_recruit_inherits_chief_tools_and_mcp
    tool        = mock('file_tool')
    mcp_clients = { 'github' => mock('client') }
    mcp_tools   = [mock('mcp_tool')]
    @chief.stubs(:local_tools).returns([tool])
    @chief.stubs(:mcp_clients).returns(mcp_clients)
    @chief.stubs(:mcp_tools).returns(mcp_tools)

    recruit = stub_robot('helper')
    recruit.stubs(:respond_to?).with(:inject_mcp!).returns(true)
    recruit.expects(:inject_mcp!).with(clients: mcp_clients, tools: mcp_tools)
    @chief.expects(:spawn).with(name: 'helper', system_prompt: 'You are helper.', local_tools: [tool]).returns(recruit)
    @crew.expects(:add_robot).with(recruit)

    AIA::Crew.recruit(name: 'helper')
  end

  def test_recruit_with_skills_uses_skill_content_as_system_prompt
    AIA.stubs(:config).returns(Object.new)
    AIA::SkillUtils.stubs(:skills_base_dir).returns('/skills')
    AIA::SkillUtils.stubs(:find_skill_dir).with('security', '/skills').returns('/skills/security')
    AIA::SkillUtils.stubs(:load_skills_content).with(%w[security], '/skills').returns('Audit for vulns.')

    reviewer = stub_robot('reviewer')
    @chief.expects(:spawn).with(name: 'reviewer', system_prompt: 'Audit for vulns.', local_tools: []).returns(reviewer)
    @crew.expects(:add_robot).with(reviewer)

    AIA::Crew.recruit(name: 'reviewer', skills: %w[security])
  end

  def test_recruit_with_unknown_skill_raises
    AIA.stubs(:config).returns(Object.new)
    AIA::SkillUtils.stubs(:skills_base_dir).returns('/skills')
    AIA::SkillUtils.stubs(:find_skill_dir).with('ghost', '/skills').returns(nil)

    error = assert_raises(AIA::CrewError) { AIA::Crew.recruit(name: 'x', skills: %w[ghost]) }
    assert_match(/Skill\(s\) not found: ghost/, error.message)
  end

  def test_reskill_drops_then_recruits_preserving_model
    larry = stub_robot('larry')
    larry.stubs(:model).returns('qwen3.6:latest')
    larry.stubs(:provider).returns('ollama')
    @crew.stubs(:crew).returns([@chief, larry])
    @crew.expects(:remove_robot).with('larry')

    new_larry = stub_robot('larry')
    AIA::Crew.expects(:recruit).with(
      name: 'larry', model: 'qwen3.6:latest', provider: 'ollama',
      skills: %w[testing], system_prompt: nil
    ).returns(new_larry)

    assert_equal new_larry, AIA::Crew.reskill('larry', skills: %w[testing])
  end

  def test_reskill_rejects_the_chief
    error = assert_raises(AIA::CrewError) { AIA::Crew.reskill('Tobor') }
    assert_match(/chief/, error.message)
  end

  def test_reskill_rejects_unknown_member
    error = assert_raises(AIA::CrewError) { AIA::Crew.reskill('ghost') }
    assert_match(/No crewmate/, error.message)
  end

  def test_recruit_rejects_duplicate_name
    @crew.stubs(:crew).returns([@chief, stub_robot('joker')])

    error = assert_raises(AIA::CrewError) { AIA::Crew.recruit(name: 'joker') }
    assert_match(/already exists/, error.message)
  end

  def test_recruit_rejects_reserved_crew_name
    error = assert_raises(AIA::CrewError) { AIA::Crew.recruit(name: 'crew') }
    assert_match(/reserved/, error.message)
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
