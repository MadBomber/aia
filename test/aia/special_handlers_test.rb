# frozen_string_literal: true

# test/aia/special_handlers_test.rb
#
# Tests for the three special mode handlers:
#   - DebateHandler: multi-round debate between robots
#   - DelegateHandler: lead robot decomposes and delegates subtasks
#   - SpawnHandler: dynamically create specialist robots

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/debate_handler'
require_relative '../../lib/aia/delegate_handler'
require_relative '../../lib/aia/task_decomposer'
require_relative '../../lib/aia/task_executor'
require_relative '../../lib/aia/spawn_handler'

# =============================================================================
# DebateHandler Tests
# =============================================================================

class DebateHandlerIntegrationTest < Minitest::Test
  def setup
    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)

    @tracker = mock('tracker')
    @tracker.stubs(:record_turn)

    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o')]
    )
    AIA.stubs(:config).returns(@config)
  end

  # --- Guard clauses ---

  def test_returns_nil_for_single_robot
    robot = mock_robot('Solo')

    handler = AIA::DebateHandler.new(robot: robot, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "debate topic"))

    assert_nil result
  end

  def test_returns_nil_for_network_with_one_robot
    network = mock_network([mock_robot('Solo')])

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "debate topic"))

    assert_nil result
  end

  # --- Basic debate flow ---

  def test_runs_debate_with_two_robots
    alice = mock_robot('Alice', response: "Alice's position")
    bob   = mock_robot('Bob',   response: "Bob's position")
    network = mock_network([alice, bob])

    # Both robots respond each round; second round Alice says CONVERGED
    alice.stubs(:run).returns(
      mock_result("Alice's initial position"),
      mock_result("CONVERGED: I agree with the consensus")
    )
    bob.stubs(:run).returns(
      mock_result("Bob's initial position"),
      mock_result("Bob's refined position")
    )

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "Should we use microservices?"))

    refute_nil result
    assert_match(/Round 1/, result)
    assert_match(/Alice/, result)
    assert_match(/Bob/, result)
  end

  def test_debate_converges_when_converged_keyword_found
    alice = mock_robot('Alice')
    bob   = mock_robot('Bob')
    network = mock_network([alice, bob])

    # First round: Alice says CONVERGED immediately
    alice.stubs(:run).returns(mock_result("CONVERGED: I agree"))
    bob.stubs(:run).returns(mock_result("Bob's view"))

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)

    @ui.expects(:display_info).with { |msg| msg.include?("Converged") }.at_least_once

    handler.handle(AIA::HandlerContext.new(prompt: "topic"))
  end

  def test_debate_runs_max_rounds_without_convergence
    alice = mock_robot('Alice')
    bob   = mock_robot('Bob')
    network = mock_network([alice, bob])

    alice.stubs(:run).returns(mock_result("Alice disagrees"))
    bob.stubs(:run).returns(mock_result("Bob disagrees"))

    # Force SimilarityScorer to always return low similarity so debate never converges
    AIA::SimilarityScorer.stubs(:score).returns([nil, 0.1])

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "contentious topic"))

    # Should have MAX_ROUNDS (5) rounds
    assert_match(/Round 5/, result)
  end

  def test_debate_records_turn_in_tracker
    alice = mock_robot('Alice')
    bob   = mock_robot('Bob')
    network = mock_network([alice, bob])

    alice.stubs(:run).returns(mock_result("CONVERGED"))
    bob.stubs(:run).returns(mock_result("response"))

    @tracker.expects(:record_turn).once.with(
      has_entries(model: 'gpt-4o', input: 'topic')
    )

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "topic"))
  end

  def test_debate_writes_to_shared_memory
    alice = mock_robot('Alice')
    bob   = mock_robot('Bob')
    memory = mock('memory')
    memory.stubs(:current_writer=)
    memory.stubs(:set)

    network = mock_network([alice, bob])
    network.stubs(:memory).returns(memory)
    # Override mock_network's respond_to?(:memory) => false
    network.stubs(:respond_to?).returns(true)
    network.stubs(:respond_to?).with(:memory).returns(true)

    alice.stubs(:run).returns(mock_result("CONVERGED"))
    bob.stubs(:run).returns(mock_result("response"))

    # Expect memory writes for each robot in each round
    memory.expects(:set).with(:debate_r0_Alice, "CONVERGED").once
    memory.expects(:set).with(:debate_r0_Bob, "response").once

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "topic"))
  end

  def test_debate_format_includes_all_rounds
    alice = mock_robot('Alice')
    bob   = mock_robot('Bob')
    network = mock_network([alice, bob])

    alice.stubs(:run).returns(
      mock_result("Round 1 Alice"),
      mock_result("CONVERGED: Round 2 Alice")
    )
    bob.stubs(:run).returns(
      mock_result("Round 1 Bob"),
      mock_result("Round 2 Bob")
    )

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "topic"))

    assert_match(/### Round 1/, result)
    assert_match(/### Round 2/, result)
    assert_match(/\*\*Alice\*\*/, result)
    assert_match(/\*\*Bob\*\*/, result)
  end

  def test_debate_context_includes_previous_round
    alice = mock_robot('Alice')
    bob   = mock_robot('Bob')
    network = mock_network([alice, bob])

    # Capture the prompts sent to alice in round 2
    round2_prompts = []
    call_count = 0
    alice.stubs(:run).with { |prompt, **_|
      call_count += 1
      round2_prompts << prompt if call_count > 1
      true
    }.returns(mock_result("response"), mock_result("CONVERGED"))

    bob.stubs(:run).returns(mock_result("Bob says hi"))

    handler = AIA::DebateHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "original topic"))

    # Round 2 prompt should contain previous round results
    refute_empty round2_prompts
    assert_match(/Previous round/, round2_prompts.first)
  end

  # --- robot= writer ---

  def test_robot_writer_updates_robot
    handler = AIA::DebateHandler.new(
      robot: mock_robot('Old'), ui_presenter: @ui, tracker: @tracker
    )

    new_network = mock_network([mock_robot('A'), mock_robot('B')])
    new_network.robots.values.each { |r| r.stubs(:run).returns(mock_result("CONVERGED")) }

    handler.robot = new_network
    result = handler.handle(AIA::HandlerContext.new(prompt: "topic"))

    refute_nil result
  end

  private

  def mock_robot(name, response: "default response")
    robot = mock(name)
    robot.stubs(:name).returns(name)
    robot.stubs(:run).returns(mock_result(response))
    robot.stubs(:with_bus)
    robot.stubs(:is_a?).returns(false)
    robot
  end

  def mock_network(robots)
    network = mock('network')
    robots_hash = robots.each_with_object({}) { |r, h| h[r.name] = r }
    network.stubs(:robots).returns(robots_hash)
    network.stubs(:is_a?).returns(false)
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:respond_to?).returns(true)
    network.stubs(:respond_to?).with(:memory).returns(false)
    network
  end

  def mock_result(text)
    result = mock("result_#{text[0..20]}")
    result.stubs(:reply).returns(text)
    result
  end
end


# =============================================================================
# DelegateHandler Tests
# =============================================================================

class DelegateHandlerIntegrationTest < Minitest::Test
  def setup
    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)

    @tracker = mock('tracker')
    @tracker.stubs(:record_turn)

    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o')]
    )
    AIA.stubs(:config).returns(@config)
  end

  # --- Guard clauses ---

  def test_returns_nil_for_single_robot
    robot = mock('robot')
    robot.stubs(:is_a?).returns(false)

    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)

    handler = AIA::DelegateHandler.new(
      robot: robot, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "task"))
  end

  def test_returns_nil_when_coordinator_unavailable
    network = mock_network([mock_robot('Alice')])

    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(false)

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "task"))
  end

  def test_returns_nil_when_coordinator_is_nil
    network = mock_network([mock_robot('Alice')])

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: nil
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "task"))
  end

  # --- Plan parsing ---

  def test_returns_nil_when_plan_parsing_fails
    lead = mock_robot('Lead')
    network = mock_network([lead, mock_robot('Worker')])

    lead.stubs(:run).returns(mock_result("I can't parse this as JSON"))

    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )

    assert_nil handler.handle(AIA::HandlerContext.new(prompt: "build something"))
  end

  # --- Successful delegation ---

  def test_delegates_work_to_robots
    lead   = mock_robot('Lead')
    worker = mock_robot('Worker')
    network = mock_network([lead, worker])

    # Lead decomposes into two tasks
    plan_json = '[{"title":"Design API","assignee":"Lead"},{"title":"Write code","assignee":"Worker"}]'
    lead.stubs(:run).returns(
      mock_result(plan_json),
      mock_result("API design complete")
    )
    worker.stubs(:run).returns(mock_result("Code written"))

    coordinator = mock_coordinator_with_plan(2)

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Build a REST API"))

    refute_nil result
    assert_match(/Step 1/, result)
    assert_match(/Step 2/, result)
    assert_match(/Design API/, result)
    assert_match(/Write code/, result)
  end

  def test_falls_back_to_first_robot_for_unknown_assignee
    lead   = mock_robot('Lead')
    worker = mock_robot('Worker')
    network = mock_network([lead, worker])

    # Assignee "Unknown" doesn't match any robot -> falls back to Lead
    plan_json = '[{"title":"Do stuff","assignee":"Unknown"}]'
    lead.stubs(:run).returns(
      mock_result(plan_json),
      mock_result("Done")
    )

    coordinator = mock_coordinator_with_plan(1)

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "task"))

    refute_nil result
    assert_match(/Lead/, result)
  end

  def test_records_turn_in_tracker
    lead   = mock_robot('Lead')
    worker = mock_robot('Worker')
    network = mock_network([lead, worker])

    plan_json = '[{"title":"Task 1","assignee":"Worker"}]'
    lead.stubs(:run).returns(mock_result(plan_json))
    worker.stubs(:run).returns(mock_result("Done"))

    coordinator = mock_coordinator_with_plan(1)

    @tracker.expects(:record_turn).once.with(
      has_entries(model: 'gpt-4o', input: 'build it')
    )

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )
    handler.handle(AIA::HandlerContext.new(prompt: "build it"))
  end

  def test_claims_and_completes_tasks_via_coordinator
    lead   = mock_robot('Lead')
    worker = mock_robot('Worker')
    network = mock_network([lead, worker])

    plan_json = '[{"title":"Task A","assignee":"Worker"}]'
    lead.stubs(:run).returns(mock_result(plan_json))
    worker.stubs(:run).returns(mock_result("Task A result"))

    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)

    step_task = mock('step_task')
    step_task.stubs(:id).returns('task-001')

    plan_result = { plan: mock('plan'), steps: [step_task] }
    coordinator.stubs(:create_plan).returns(plan_result)

    coordinator.expects(:claim_task).with('task-001', 'Worker').once
    coordinator.expects(:complete_task).with('task-001', result: anything, robot_name: 'Worker').once

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )
    handler.handle(AIA::HandlerContext.new(prompt: "task"))
  end

  def test_writes_results_to_shared_memory
    lead   = mock_robot('Lead')
    worker = mock_robot('Worker')
    memory = mock('memory')
    memory.stubs(:current_writer=)
    memory.stubs(:set)

    network = mock_network([lead, worker])
    # Override mock_network's respond_to?(:memory) => false
    network.stubs(:respond_to?).returns(true)
    network.stubs(:respond_to?).with(:memory).returns(true)
    network.stubs(:memory).returns(memory)

    plan_json = '[{"title":"Task A","assignee":"Worker"}]'
    lead.stubs(:run).returns(mock_result(plan_json))
    worker.stubs(:run).returns(mock_result("Done"))

    coordinator = mock_coordinator_with_plan(1)

    memory.expects(:set).with(:delegate_step_0, has_entries(robot: 'Worker', task: 'Task A')).once

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )
    handler.handle(AIA::HandlerContext.new(prompt: "task"))
  end

  def test_step_context_includes_prior_results
    lead   = mock_robot('Lead')
    worker = mock_robot('Worker')
    network = mock_network([lead, worker])

    plan_json = '[{"title":"Step 1","assignee":"Lead"},{"title":"Step 2","assignee":"Worker"}]'

    # Capture step 2 prompt
    step2_prompt = nil
    lead.stubs(:run).returns(
      mock_result(plan_json),
      mock_result("Step 1 done")
    )
    worker.stubs(:run).with { |prompt, **_|
      step2_prompt = prompt
      true
    }.returns(mock_result("Step 2 done"))

    coordinator = mock_coordinator_with_plan(2)

    handler = AIA::DelegateHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker, task_coordinator: coordinator
    )
    handler.handle(AIA::HandlerContext.new(prompt: "original request"))

    refute_nil step2_prompt
    assert_match(/Prior work/, step2_prompt)
    assert_match(/Step 1 done/, step2_prompt)
  end

  # --- robot= writer ---

  def test_robot_writer_updates_robot
    handler = AIA::DelegateHandler.new(
      robot: mock_robot('Old'), ui_presenter: @ui, tracker: @tracker,
      task_coordinator: mock('coordinator')
    )

    new_network = mock_network([mock_robot('New')])
    handler.robot = new_network

    # Should use new network (returns nil because only 1 robot but coordinator check runs)
    handler.instance_variable_get(:@task_coordinator).stubs(:available?).returns(false)
    result = handler.handle(AIA::HandlerContext.new(prompt: "task"))
    assert_nil result
  end

  private

  def mock_robot(name)
    robot = mock(name)
    robot.stubs(:name).returns(name)
    robot.stubs(:run).returns(mock_result("default"))
    robot.stubs(:is_a?).returns(false)
    robot
  end

  def mock_network(robots)
    network = mock('network')
    robots_hash = robots.each_with_object({}) { |r, h| h[r.name] = r }
    network.stubs(:robots).returns(robots_hash)
    network.stubs(:is_a?).returns(false)
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:respond_to?).returns(true)
    network.stubs(:respond_to?).with(:memory).returns(false)
    network
  end

  def mock_result(text)
    result = mock("result_#{text[0..15]}")
    result.stubs(:reply).returns(text)
    result
  end

  def mock_coordinator_with_plan(step_count)
    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)

    step_tasks = step_count.times.map do |i|
      step = mock("step_#{i}")
      step.stubs(:id).returns("task-#{i}")
      step
    end

    plan_result = { plan: mock('plan'), steps: step_tasks }
    coordinator.stubs(:create_plan).returns(plan_result)
    coordinator.stubs(:claim_task)
    coordinator.stubs(:complete_task)

    coordinator
  end
end


# =============================================================================
# SpawnHandler Tests
# =============================================================================

class SpawnHandlerIntegrationTest < Minitest::Test
  def setup
    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)

    @tracker = mock('tracker')
    @tracker.stubs(:record_turn)

    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o')]
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:task_coordinator).returns(nil)
  end

  # --- With explicit specialist type ---

  def test_spawn_explicit_specialist
    primary = mock_robot('Primary')
    specialist = mock_robot('security_expert')

    primary.stubs(:spawn).with(
      has_entries(name: 'security_expert')
    ).returns(specialist)

    specialist.stubs(:run).returns(mock_result("Security analysis complete"))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "Check for SQL injection", specialist_type: "security_expert"))

    assert_equal "Security analysis complete", result
  end

  def test_spawn_explicit_specialist_with_correct_prompt
    primary = mock_robot('Primary')
    specialist = mock_robot('data_scientist')

    primary.stubs(:spawn).with(
      has_entries(
        name: 'data_scientist',
        system_prompt: includes('data_scientist specialist')
      )
    ).returns(specialist)

    specialist.stubs(:run).returns(mock_result("Analysis"))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "Analyze trends", specialist_type: "data_scientist"))
  end

  # --- With auto-detection ---

  def test_spawn_auto_detect_specialist
    primary = mock_robot('Primary')
    specialist = mock_robot('auto_specialist')

    # Primary detects the specialist type
    primary.stubs(:run).returns(mock_result("security_expert\nYou specialize in security audits."))
    primary.stubs(:spawn).with(
      has_entries(name: 'security_expert')
    ).returns(specialist)

    specialist.stubs(:run).returns(mock_result("Audit complete"))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "Check for vulnerabilities"))

    assert_equal "Audit complete", result
  end

  def test_auto_detect_normalizes_specialist_name
    primary = mock_robot('Primary')
    specialist = mock_robot('normalized')

    # Primary returns a name with spaces and mixed case
    primary.stubs(:run).returns(mock_result("Data Scientist\nYou analyze data."))
    primary.stubs(:spawn).with(
      has_entries(name: 'data_scientist')
    ).returns(specialist)

    specialist.stubs(:run).returns(mock_result("Done"))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "Analyze this data"))
  end

  # --- Specialist caching ---

  def test_specialists_are_cached_for_reuse
    primary = mock_robot('Primary')
    specialist = mock_robot('code_reviewer')

    primary.expects(:spawn).once.returns(specialist)
    specialist.stubs(:run).returns(mock_result("Review 1"), mock_result("Review 2"))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "Review PR 1", specialist_type: "code_reviewer"))
    handler.handle(AIA::HandlerContext.new(prompt: "Review PR 2", specialist_type: "code_reviewer"))
  end

  def test_different_types_spawn_different_specialists
    primary = mock_robot('Primary')
    security = mock_robot('security')
    perf = mock_robot('performance')

    primary.stubs(:spawn).with(has_entries(name: 'security')).returns(security)
    primary.stubs(:spawn).with(has_entries(name: 'performance')).returns(perf)

    security.stubs(:run).returns(mock_result("Secure"))
    perf.stubs(:run).returns(mock_result("Fast"))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)

    r1 = handler.handle(AIA::HandlerContext.new(prompt: "Check security", specialist_type: "security"))
    r2 = handler.handle(AIA::HandlerContext.new(prompt: "Check speed", specialist_type: "performance"))

    assert_equal "Secure", r1
    assert_equal "Fast", r2
  end

  # --- Network support ---

  def test_uses_first_robot_from_network
    alice = mock_robot('Alice')
    bob   = mock_robot('Bob')
    network = mock_network([alice, bob])

    specialist = mock_robot('specialist')
    alice.expects(:spawn).returns(specialist)
    specialist.stubs(:run).returns(mock_result("Done"))

    handler = AIA::SpawnHandler.new(robot: network, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "task", specialist_type: "specialist"))
  end

  # --- Tracker integration ---

  def test_records_turn_in_tracker
    primary = mock_robot('Primary')
    specialist = mock_robot('expert')

    primary.stubs(:spawn).returns(specialist)
    specialist.stubs(:run).returns(mock_result("answer"))

    @tracker.expects(:record_turn).once.with(
      has_entries(model: 'gpt-4o', input: 'question')
    )

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "question", specialist_type: "expert"))
  end

  # --- TrakFlow integration ---

  def test_creates_trakflow_task_when_coordinator_available
    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)
    coordinator.expects(:create_task).once.with(
      anything,
      has_entries(assignee: 'expert', labels: ['specialist', 'spawned'])
    )
    AIA.stubs(:task_coordinator).returns(coordinator)

    primary = mock_robot('Primary')
    specialist = mock_robot('expert')
    primary.stubs(:spawn).returns(specialist)
    specialist.stubs(:run).returns(mock_result("done"))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "task", specialist_type: "expert"))
  end

  def test_skips_trakflow_when_coordinator_nil
    AIA.stubs(:task_coordinator).returns(nil)

    primary = mock_robot('Primary')
    specialist = mock_robot('expert')
    primary.stubs(:spawn).returns(specialist)
    specialist.stubs(:run).returns(mock_result("done"))

    # Should not raise
    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    result = handler.handle(AIA::HandlerContext.new(prompt: "task", specialist_type: "expert"))

    assert_equal "done", result
  end

  # --- robot= writer ---

  def test_robot_writer_updates_robot
    handler = AIA::SpawnHandler.new(
      robot: mock_robot('Old'), ui_presenter: @ui, tracker: @tracker
    )

    new_robot = mock_robot('New')
    specialist = mock_robot('spec')
    new_robot.stubs(:spawn).returns(specialist)
    specialist.stubs(:run).returns(mock_result("from new"))

    handler.robot = new_robot
    result = handler.handle(AIA::HandlerContext.new(prompt: "task", specialist_type: "spec"))

    assert_equal "from new", result
  end

  private

  def mock_robot(name)
    robot = mock(name)
    robot.stubs(:name).returns(name)
    robot.stubs(:bus).returns(nil)
    robot.stubs(:respond_to?).returns(true)
    robot.stubs(:respond_to?).with(:bus).returns(true)
    robot.stubs(:with_bus)
    robot.stubs(:is_a?).returns(false)
    robot
  end

  def mock_network(robots)
    network = mock('network')
    robots_hash = robots.each_with_object({}) { |r, h| h[r.name] = r }
    network.stubs(:robots).returns(robots_hash)
    network.stubs(:is_a?).returns(false)
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network
  end

  def mock_result(text)
    result = mock("result_#{text[0..15]}")
    result.stubs(:reply).returns(text)
    result
  end
end
