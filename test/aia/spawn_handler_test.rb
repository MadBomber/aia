# frozen_string_literal: true
# test/aia/spawn_handler_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia/spawn_handler'

class SpawnHandlerTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, debug: false, verbose: false),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      mcp_servers: []
    )
    AIA.stubs(:config).returns(@config)
    @turn_state = AIA::TurnState.new
    AIA.stubs(:turn_state).returns(@turn_state)
    AIA.stubs(:task_coordinator).returns(nil)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_ai_response)
    @ui.stubs(:display_separator)

    @tracker = mock('session_tracker')
    @tracker.stubs(:record_turn)
  end

  def test_spawn_with_explicit_type
    specialist = mock('specialist')
    specialist.stubs(:run).returns(OpenStruct.new(reply: "Expert answer here"))

    primary = mock('primary')
    primary.stubs(:name).returns("Alice")
    primary.stubs(:respond_to?).with(:bus).returns(false)
    primary.stubs(:bus).returns(nil)
    primary.stubs(:with_bus)
    primary.expects(:spawn).with(
      name: "security_expert",
      system_prompt: "You are a security_expert specialist. Answer precisely within your domain of expertise."
    ).returns(specialist)

    robot = mock('robot')
    robot.stubs(:is_a?).with(RobotLab::Network).returns(false)

    handler = AIA::SpawnHandler.new(
      robot: primary, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Is this secure?", specialist_type: "security_expert"))

    assert_equal "Expert answer here", result
  end

  def test_spawn_with_auto_detect
    specialist = mock('specialist')
    specialist.stubs(:run).returns(OpenStruct.new(reply: "Database insight"))

    primary = mock('primary')
    primary.stubs(:name).returns("Alice")
    primary.stubs(:respond_to?).with(:bus).returns(true)
    primary.stubs(:bus).returns(mock('bus'))
    primary.stubs(:with_bus)

    # First call: detect specialist type
    primary.stubs(:run)
           .returns(OpenStruct.new(reply: "database_expert\nYou are a database optimization specialist."))
           .then.returns(OpenStruct.new(reply: "Database insight"))

    primary.expects(:spawn).with(
      name: "database_expert",
      system_prompt: "You are a database optimization specialist."
    ).returns(specialist)

    handler = AIA::SpawnHandler.new(
      robot: primary, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "How do I optimize this query?"))

    assert_equal "Database insight", result
  end

  def test_spawn_caches_specialists
    specialist = mock('specialist')
    specialist.stubs(:run).returns(OpenStruct.new(reply: "Answer"))

    primary = mock('primary')
    primary.stubs(:name).returns("Alice")
    primary.stubs(:respond_to?).with(:bus).returns(true)
    primary.stubs(:bus).returns(mock('bus'))
    primary.stubs(:with_bus)
    # spawn should only be called once
    primary.expects(:spawn).once.returns(specialist)

    handler = AIA::SpawnHandler.new(
      robot: primary, ui_presenter: @ui, tracker: @tracker
    )

    handler.handle(AIA::HandlerContext.new(prompt: "Q1", specialist_type: "expert"))
    handler.handle(AIA::HandlerContext.new(prompt: "Q2", specialist_type: "expert"))
  end

  def test_spawn_uses_first_robot_from_network
    specialist = mock('specialist')
    specialist.stubs(:run).returns(OpenStruct.new(reply: "Answer"))

    primary = mock('primary')
    primary.stubs(:name).returns("Alice")
    primary.stubs(:respond_to?).with(:bus).returns(true)
    primary.stubs(:bus).returns(mock('bus'))
    primary.stubs(:with_bus)
    primary.stubs(:spawn).returns(specialist)

    network = mock('network')
    network.stubs(:is_a?).with(RobotLab::Network).returns(true)
    network.stubs(:robots).returns({ alice: primary })
    network.robots.stubs(:values).returns([primary])

    handler = AIA::SpawnHandler.new(
      robot: network, ui_presenter: @ui, tracker: @tracker
    )

    result = handler.handle(AIA::HandlerContext.new(prompt: "Question", specialist_type: "test_expert"))
    assert_equal "Answer", result
  end

  def test_spawn_tracks_in_trakflow_when_available
    specialist = mock('specialist')
    specialist.stubs(:run).returns(OpenStruct.new(reply: "Answer"))

    coordinator = mock('coordinator')
    coordinator.stubs(:available?).returns(true)
    coordinator.expects(:create_task).with(
      anything,
      assignee: "test_expert",
      labels: ["specialist", "spawned"],
      creator: "Alice"
    )
    AIA.stubs(:task_coordinator).returns(coordinator)

    primary = mock('primary')
    primary.stubs(:name).returns("Alice")
    primary.stubs(:respond_to?).with(:bus).returns(true)
    primary.stubs(:bus).returns(mock('bus'))
    primary.stubs(:with_bus)
    primary.stubs(:spawn).returns(specialist)

    handler = AIA::SpawnHandler.new(
      robot: primary, ui_presenter: @ui, tracker: @tracker
    )

    handler.handle(AIA::HandlerContext.new(prompt: "Question", specialist_type: "test_expert"))
  end

  # ---------------------------------------------------------------------------
  # 5.2 — Lifecycle: max cache size + cleanup!
  # ---------------------------------------------------------------------------

  def test_cleanup_clears_all_cached_specialists
    specialist = mock('specialist')
    specialist.stubs(:run).returns(OpenStruct.new(reply: "Answer"))

    primary = mock('primary')
    primary.stubs(:name).returns("Alice")
    primary.stubs(:respond_to?).with(:bus).returns(true)
    primary.stubs(:bus).returns(mock('bus'))
    primary.stubs(:with_bus)
    primary.stubs(:spawn).returns(specialist)

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)
    handler.handle(AIA::HandlerContext.new(prompt: "Q", specialist_type: "expert_a"))
    handler.handle(AIA::HandlerContext.new(prompt: "Q", specialist_type: "expert_b"))

    handler.cleanup!
    assert_equal 0, handler.instance_variable_get(:@spawned).size
  end

  def test_cache_evicts_oldest_when_max_size_exceeded
    specialists = AIA::SpawnHandler::MAX_CACHE_SIZE.times.map do |i|
      s = mock("specialist_#{i}")
      s.stubs(:run).returns(OpenStruct.new(reply: "Answer #{i}"))
      s
    end

    primary = mock('primary')
    primary.stubs(:name).returns("Alice")
    primary.stubs(:respond_to?).with(:bus).returns(true)
    primary.stubs(:bus).returns(mock('bus'))
    primary.stubs(:with_bus)

    call_count = 0
    primary.stubs(:spawn).with { true }.returns(*(specialists + [specialists[0]]))

    handler = AIA::SpawnHandler.new(robot: primary, ui_presenter: @ui, tracker: @tracker)

    # Fill the cache to MAX_CACHE_SIZE
    AIA::SpawnHandler::MAX_CACHE_SIZE.times do |i|
      handler.handle(AIA::HandlerContext.new(prompt: "Q#{i}", specialist_type: "role_#{i}"))
    end

    cache = handler.instance_variable_get(:@spawned)
    assert_equal AIA::SpawnHandler::MAX_CACHE_SIZE, cache.size

    # Spawning one more should evict the oldest ("role_0")
    handler.handle(AIA::HandlerContext.new(prompt: "New Q", specialist_type: "role_new"))

    cache = handler.instance_variable_get(:@spawned)
    assert_equal AIA::SpawnHandler::MAX_CACHE_SIZE, cache.size
    refute cache.key?("role_0"), "Oldest entry should have been evicted"
    assert cache.key?("role_new"), "New entry should be present"
  end

  def test_force_spawn_flag_and_type
    @turn_state.force_spawn = true
    @turn_state.spawn_type = "data_scientist"

    assert @turn_state.force_spawn
    assert_equal "data_scientist", @turn_state.spawn_type

    @turn_state.clear!
    refute @turn_state.force_spawn
    assert_nil @turn_state.spawn_type
  end
end
