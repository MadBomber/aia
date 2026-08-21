# frozen_string_literal: true

# test/aia/directives/execution_directives_test.rb

require_relative '../../test_helper'
require 'ostruct'

class ExecutionDirectivesTest < Minitest::Test
  def setup
    @mock_flags   = OpenStruct.new(allow_ruby_eval: false)
    @mock_audio   = OpenStruct.new(speech_model: nil, voice: nil)
    @mock_config  = OpenStruct.new(flags: @mock_flags, audio: @mock_audio)
    AIA.stubs(:config).returns(@mock_config)

    @mock_turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(@mock_turn_state)

    @instance = AIA::ExecutionDirectives.new
  end

  # ---------------------------------------------------------------------------
  # /add_recruit and /drop_recruit directives
  # ---------------------------------------------------------------------------

  def test_add_recruit_recruits_via_crew
    robot = mock('robot')
    robot.stubs(:name).returns('joker')
    AIA::Crew.expects(:recruit).returns(robot)

    out = @instance.add_recruit(%w[joker ollama/qwen3.6:latest You are the joker])

    assert_match(/Recruited 'joker'/, out)
    assert_match(%r{ollama/qwen3.6:latest}, out)
  end

  def test_add_recruit_usage_when_empty
    assert_match(/Usage/, @instance.add_recruit([]))
  end

  def test_add_recruit_reports_crew_error
    AIA::Crew.stubs(:recruit).raises(AIA::CrewError, 'boom')

    assert_match(/Recruit failed: boom/, @instance.add_recruit(%w[joker ollama/qwen hi]))
  end

  def test_drop_recruit_drops_via_crew
    AIA::Crew.expects(:drop).with('joker')

    assert_match(/Dropped 'joker'/, @instance.drop_recruit(['joker']))
  end

  def test_drop_recruit_reports_crew_error
    AIA::Crew.stubs(:drop).raises(AIA::CrewError, 'nope')

    assert_match(/Drop failed: nope/, @instance.drop_recruit(['ghost']))
  end

  def test_add_recruit_with_skill_token_reports_skills
    robot = mock('robot')
    robot.stubs(:name).returns('reviewer')
    AIA::Crew.expects(:recruit).returns(robot)

    out = @instance.add_recruit(%w[reviewer - skill:security focus on auth])

    assert_match(/Recruited 'reviewer'/, out)
    assert_match(/skills: security/, out)
  end

  def test_reskill_resets_member_with_skills
    robot = mock('robot')
    robot.stubs(:name).returns('larry')
    AIA::Crew.expects(:reskill).with('larry', skills: %w[testing], system_prompt: 'be terse').returns(robot)

    out = @instance.reskill(%w[larry skill:testing be terse])

    assert_match(/Reskilled 'larry' with testing/, out)
  end

  def test_reskill_usage_when_empty
    assert_match(/Usage/, @instance.reskill([]))
  end

  def test_reskill_reports_crew_error
    AIA::Crew.stubs(:reskill).raises(AIA::CrewError, 'nope')

    assert_match(/Reskill failed: nope/, @instance.reskill(%w[ghost skill:x]))
  end

  # ---------------------------------------------------------------------------
  # /ruby directive — guarded by allow_ruby_eval flag
  # ---------------------------------------------------------------------------

  def test_ruby_returns_empty_string_when_allow_ruby_eval_not_set
    @mock_flags.allow_ruby_eval = false
    result = nil
    out, = capture_io { result = @instance.ruby(['1 + 1']) }
    assert_equal '', result
    assert_match(/allow_ruby_eval/, out)
  end

  def test_ruby_evaluates_code_when_allowed
    @mock_flags.allow_ruby_eval = true
    result = @instance.ruby(['1 + 1'])
    assert_equal '2', result
  end

  def test_ruby_returns_error_string_on_exception_when_allowed
    @mock_flags.allow_ruby_eval = true
    result = @instance.ruby(['raise "boom"'])
    assert_match(/boom/, result)
  end

  # ---------------------------------------------------------------------------
  # Mode-setting directives — set AIA.turn_state flags
  # ---------------------------------------------------------------------------

  def test_concurrent_sets_turn_state_flag
    @instance.concurrent([])
    assert_equal true, AIA.turn_state.force_concurrent_mcp
  end

  def test_verify_sets_turn_state_flag
    @instance.verify([])
    assert_equal true, AIA.turn_state.force_verify
  end

  def test_decompose_sets_turn_state_flag
    @instance.decompose([])
    assert_equal true, AIA.turn_state.force_decompose
  end

  def test_debate_sets_turn_state_flag
    @instance.debate([])
    assert_equal true, AIA.turn_state.force_debate
  end

  def test_delegate_sets_turn_state_flag
    @instance.delegate([])
    assert_equal true, AIA.turn_state.force_delegate
  end

  def test_spawn_sets_flag_and_specialist_type
    @instance.spawn(['mysql-expert'])
    assert_equal true,          AIA.turn_state.force_spawn
    assert_equal 'mysql-expert', AIA.turn_state.spawn_type
  end

  def test_spawn_with_explicit_spec_sets_spawn_spec
    @instance.spawn(%w[researcher ollama/qwen3.6:latest You are careful])

    assert AIA.turn_state.force_spawn
    assert_nil AIA.turn_state.spawn_type
    spec = AIA.turn_state.spawn_spec
    assert_equal 'researcher', spec[:name]
    assert_equal 'qwen3.6:latest', spec[:model]
    assert_equal 'ollama', spec[:provider]
    assert_equal 'You are careful', spec[:system_prompt]
  end

  def test_orchestrate_sets_turn_state_flag
    @instance.orchestrate([])
    assert_equal true, AIA.turn_state.force_orchestrate
  end

  def test_say_calls_system_and_returns_empty_string
    @instance.expects(:system).with({}, 'say', 'hello').returns(nil)
    result = @instance.say(['hello'])
    assert_equal '', result
  end
end
