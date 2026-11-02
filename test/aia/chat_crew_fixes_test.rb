# frozen_string_literal: true

require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'
require_relative '../../lib/aia/spawn_handler'
require_relative '../../lib/aia/verification_network'

# @mentions that name nobody are ordinary text.
class UnmatchedMentionTest < Minitest::Test
  def setup
    AIA.stubs(:config).returns(OpenStruct.new(flags: OpenStruct.new(chat: true), audio: OpenStruct.new))
    AIA.stubs(:speak?).returns(false)
    @ui = mock('ui')
    @router = AIA::MentionRouter.new(ui_presenter: @ui, tracker: mock('tracker'), streaming_runner: mock('runner'))
    alice = mock('Alice')
    alice.stubs(:name).returns('Alice')
    @network = mock('network')
    @network.stubs(:network?).returns(true)
    @network.stubs(:crew).returns([alice])
  end

  def handle(prompt) = @router.handle(AIA::HandlerContext.new(robot: @network, prompt: prompt))

  def test_email_address_goes_to_the_model
    @ui.expects(:display_info).never
    refute handle('write to bob@example.com about the invoice')
  end

  def test_unknown_mention_in_the_body_goes_to_the_model
    @ui.expects(:display_info).never
    refute handle('what does @deprecated mean in Ruby?')
  end

  def test_unknown_leading_mention_is_reported_and_held_back
    @ui.expects(:display_info).with(regexp_matches(/Unknown robot: @Alcie/))
    assert handle('@Alcie summarize this')
  end
end

class CompareArgsTest < Minitest::Test
  def test_the_whole_argument_string_is_the_prompt
    prompt, models = AIA::ModelDirectives.new.parse_compare_args(%w[explain closures --models a,b in Ruby])
    assert_equal 'explain closures in Ruby', prompt
    assert_equal %w[a b], models
  end

  def test_no_words_is_no_prompt
    prompt, = AIA::ModelDirectives.new.parse_compare_args(%w[--models a,b])
    assert_nil prompt
  end
end

class CrewNameCaseTest < Minitest::Test
  def setup
    @chief = robot('Tobor')
    @joker = robot('Joker')
    @crew = mock('crew')
    @crew.stubs(:chief).returns(@chief)
    @crew.stubs(:crew).returns([@chief, @joker])
    @crew.stubs(:respond_to?).with(:add_robot).returns(true)
    AIA.stubs(:client).returns(@crew)
  end

  def robot(name)
    r = mock(name)
    r.stubs(:name).returns(name)
    r
  end

  def test_drop_ignores_case
    @crew.expects(:remove_robot).with('Joker').returns(@joker)
    AIA::Crew.drop('joker')
  end

  def test_chief_check_ignores_case
    assert_raises(AIA::CrewError) { AIA::Crew.drop('TOBOR') }
  end

  def test_duplicate_check_ignores_case
    error = assert_raises(AIA::CrewError) { AIA::Crew.recruit(name: 'JOKER') }
    assert_match(/already exists/, error.message)
  end

  def test_reskill_ignores_case_and_keeps_the_name
    @joker.stubs(:model).returns('m')
    @joker.stubs(:provider).returns(nil)
    @crew.expects(:remove_robot).with('Joker')
    AIA::Crew.expects(:recruit).with(has_entries(name: 'Joker')).returns(@joker)
    AIA::Crew.reskill('joker')
  end
end

class SpawnedSpecialistTest < Minitest::Test
  def setup
    AIA.stubs(:config).returns(OpenStruct.new(models: [OpenStruct.new(name: 'gpt-4o-mini')]))
    AIA.stubs(:task_coordinator).returns(nil)
    AIA::ToolApprover.stubs(:options).returns({})
    @ui = mock('ui')
    @ui.stubs(:display_info)
    @tracker = mock('tracker')
    @tracker.stubs(:record_turn)
    @primary = mock('primary')
    @primary.stubs(:name).returns('Tobor')
    @primary.stubs(:chief).returns(@primary)
    @primary.stubs(:respond_to?).with(:bus).returns(true)
    @primary.stubs(:bus).returns(mock('bus'))
    @specialist = mock('specialist')
    @specialist.stubs(:run).returns(OpenStruct.new(reply: 'done'))
  end

  def run_spawn(spec)
    handler = AIA::SpawnHandler.new(robot: @primary, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: 'go', spawn_spec: spec))
  end

  def test_specialist_gets_the_chiefs_tools_and_mcp_servers
    tool = mock('tool')
    server = mock('server')
    AIA::Crew.stubs(:chief_local_tools).with(@primary).returns([tool])
    AIA::Crew.stubs(:chief_mcp).with(@primary).returns({ mcp: [server] })
    @primary.expects(:spawn).with(has_entries(local_tools: [tool], mcp: [server])).returns(@specialist)

    assert_equal 'done', run_spawn(name: 'helper')
  end

  def test_specialist_gets_its_skills
    AIA::Crew.stubs(:chief_local_tools).returns([])
    AIA::Crew.stubs(:chief_mcp).returns({})
    AIA::Crew.stubs(:skills_prompt).with(['tidy']).returns('Keep it tidy.')
    @primary.expects(:spawn).with(has_entries(system_prompt: "Keep it tidy.\n\nBe brief.")).returns(@specialist)

    run_spawn(name: 'helper', skills: ['tidy'], system_prompt: 'Be brief.')
  end
end

class VerificationProviderTest < Minitest::Test
  # A stand-in for the network DSL, so the build block runs.
  class FakeDSL
    def task(*) = nil
  end

  def test_verifiers_are_built_with_the_model_spec
    model = OpenStruct.new(name: 'qwen3', provider: 'ollama')
    config = OpenStruct.new(models: [model])
    AIA::RobotFactory.stubs(:build_run_config).returns(nil)
    AIA::ToolLoader.stubs(:filtered_tools).returns([])
    AIA::RobotFactory.stubs(:mcp_servers).returns([])
    AIA::RobotFactory.expects(:build_robot).with(model, anything).times(3).returns(mock('robot'))

    original = RobotLab.method(:create_network)
    RobotLab.define_singleton_method(:create_network) { |**_, &blk| FakeDSL.new.instance_eval(&blk) || :network }
    AIA::VerificationNetwork.build(config)
  ensure
    RobotLab.define_singleton_method(:create_network, original)
  end
end

class TaskBoardStartupTest < Minitest::Test
  def test_prepare_task_board_starts_the_coordinator_when_trakflow_is_available
    coordinator = AIA::StartupCoordinator.new(robot: nil, ui_presenter: nil)
    coordinator.stubs(:trakflow_available?).returns(true)
    coordinator.expects(:initialize_task_coordinator)
    coordinator.prepare_task_board
  end

  def test_prepare_task_board_skips_without_trakflow
    coordinator = AIA::StartupCoordinator.new(robot: nil, ui_presenter: nil)
    coordinator.stubs(:trakflow_available?).returns(false)
    coordinator.expects(:initialize_task_coordinator).never
    coordinator.prepare_task_board
  end
end
