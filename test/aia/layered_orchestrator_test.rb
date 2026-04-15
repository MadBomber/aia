# frozen_string_literal: true
# test/aia/layered_orchestrator_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/layered_orchestrator'
require 'tmpdir'

class LayeredOrchestratorTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_ai_response)
    @ui.stubs(:display_separator)

    @tracker = mock('tracker')
    @tracker.stubs(:record_turn)

    @robot = mock('robot')
    @robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    @robot.stubs(:name).returns("Tobor")

    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', provider: nil)],
      mcp_servers: []
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:turn_state).returns(AIA::TurnState.new)

    @orchestrator = AIA::LayeredOrchestrator.new(
      robot: @robot,
      ui_presenter: @ui,
      tracker: @tracker,
      build_dir: @tmp_dir
    )
    @orchestrator.stubs(:say)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  # =========================================================================
  # run_leads_wave — Tier 2 parallel lead execution
  # =========================================================================

  def test_run_leads_wave_returns_tasks_for_successful_layer
    layer = {
      'name'         => 'infra',
      'title'        => 'Infrastructure',
      'requirements' => 'database setup'
    }

    lead_probe = mock('infra-lead')
    lead_probe.stubs(:run).returns(
      OpenStruct.new(
        content: '[{"title":"Create users table","specialist":"migration-writer","artifact":"db/001_users.rb","prompt":"write migration"}]'
      )
    )
    @orchestrator.stubs(:build_probe).with('infra-lead').returns(lead_probe)

    result = @orchestrator.send(:run_leads_wave, [layer])

    assert_equal 1, result['infra'].size
    assert_equal 'Create users table', result['infra'].first['title']
  end

  def test_run_leads_wave_records_empty_for_failing_lead
    layer = {
      'name'         => 'infra',
      'title'        => 'Infrastructure',
      'requirements' => 'r1'
    }

    failing_probe = mock('infra-lead')
    failing_probe.stubs(:run).raises(RuntimeError, "model connection refused")
    @orchestrator.stubs(:build_probe).with('infra-lead').returns(failing_probe)

    result = @orchestrator.send(:run_leads_wave, [layer])

    assert result.key?('infra')
    assert_empty result['infra']
  end

  # =========================================================================
  # run_specialists_wave — Tier 3 parallel specialist execution
  # =========================================================================

  def test_run_specialists_wave_marks_failed_specialist_with_failed_marker
    task = {
      'title'      => 'Create users table',
      'specialist' => 'migration-writer',
      'artifact'   => 'db/001_users.rb',
      'prompt'     => 'write the migration'
    }
    layer_task_map = { 'infra' => [task] }

    failing_probe = mock('migration-writer-specialist')
    failing_probe.stubs(:run).raises(RuntimeError, "specialist timed out")
    @orchestrator.stubs(:build_probe).with('migration-writer-specialist').returns(failing_probe)
    @orchestrator.stubs(:save_artifact)

    results = @orchestrator.send(:run_specialists_wave, layer_task_map)

    key = 'infra|db/001_users.rb'
    assert results.key?(key)
    assert_match(/FAILED/, results[key][:output])
  end

  def test_run_specialists_wave_continues_when_one_specialist_fails
    tasks = [
      { 'title' => 'Task A', 'specialist' => 'spec-a', 'artifact' => 'a.rb', 'prompt' => 'do a' },
      { 'title' => 'Task B', 'specialist' => 'spec-b', 'artifact' => 'b.rb', 'prompt' => 'do b' }
    ]
    layer_task_map = { 'infra' => tasks }

    probe_a = mock('spec-a-specialist')
    probe_a.stubs(:run).raises(RuntimeError, "spec-a crashed")

    probe_b = mock('spec-b-specialist')
    probe_b.stubs(:run).returns(OpenStruct.new(content: "spec-b output content"))

    @orchestrator.stubs(:build_probe).with('spec-a-specialist').returns(probe_a)
    @orchestrator.stubs(:build_probe).with('spec-b-specialist').returns(probe_b)
    @orchestrator.stubs(:save_artifact)

    results = @orchestrator.send(:run_specialists_wave, layer_task_map)

    assert results.key?('infra|a.rb'),    "spec-a key missing"
    assert results.key?('infra|b.rb'),    "spec-b key missing"
    assert_match(/FAILED/, results['infra|a.rb'][:output])
    assert_equal 'spec-b output content', results['infra|b.rb'][:output]
  end

  def test_run_specialists_wave_returns_empty_when_no_tasks
    results = @orchestrator.send(:run_specialists_wave, { 'infra' => [], 'data' => [] })
    assert_empty results
  end

  # =========================================================================
  # handle integration — wave orchestration via handle()
  # =========================================================================

  def test_handle_returns_nil_when_all_leads_produce_empty_tasks
    @orchestrator.stubs(:decompose_to_layers).returns([
      { 'name' => 'infra', 'title' => 'Infrastructure', 'requirements' => 'r1' },
      { 'name' => 'data',  'title' => 'Data',            'requirements' => 'r2' }
    ])
    @orchestrator.stubs(:run_leads_wave).returns({ 'infra' => [], 'data' => [] })

    result = @orchestrator.handle(AIA::HandlerContext.new(prompt: "build a Rails app"))
    assert_nil result
  end

  def test_build_layer_results_assembles_correct_structure
    layers = [
      { 'name' => 'infra', 'title' => 'Infrastructure', 'requirements' => 'r1' }
    ]
    task = {
      'title'      => 'Create DB',
      'specialist' => 'migration-writer',
      'artifact'   => 'db/001.rb',
      'prompt'     => 'write migration'
    }
    layer_task_map = { 'infra' => [task] }
    specialist_results = {
      'infra|db/001.rb' => {
        task: 'Create DB', specialist: 'migration-writer',
        artifact: 'db/001.rb', output: 'CREATE TABLE users'
      }
    }

    @orchestrator.stubs(:synthesize_layer_from_results).returns("Infrastructure layer summary")

    result = @orchestrator.send(:build_layer_results, layers, layer_task_map, specialist_results)

    assert_equal 1, result.size
    assert_equal 'Infrastructure', result.first[:layer]
    assert_equal 1, result.first[:tasks].size
    assert_equal 'Infrastructure layer summary', result.first[:summary]
    assert_equal 'CREATE TABLE users', result.first[:tasks].first[:output]
  end
end
