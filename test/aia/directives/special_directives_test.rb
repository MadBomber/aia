# frozen_string_literal: true
# test/aia/directives/special_directives_test.rb

require_relative '../../test_helper'

class SpecialDirectivesTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, debug: false, verbose: false, consensus: false),
      rules: OpenStruct.new(dir: nil, enabled: false),
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      pipeline: [],
      context_files: [],
      mcp_servers: []
    )
    AIA.stubs(:config).returns(@config)
  end

  # --- Execution Directives ---

  def test_concurrent_directive_sets_force_flag
    directive = AIA::ExecutionDirectives.new
    result = directive.concurrent([], nil)

    assert_equal true, @config.instance_variable_get(:@force_concurrent_mcp)
    assert_includes result, "Concurrent MCP mode enabled"
  end

  def test_conc_is_alias_for_concurrent
    directive = AIA::ExecutionDirectives.new
    assert directive.respond_to?(:conc)
  end

  def test_verify_directive_sets_force_flag
    directive = AIA::ExecutionDirectives.new
    result = directive.verify([], nil)

    assert_equal true, @config.instance_variable_get(:@force_verify)
    assert_includes result, "Verification mode enabled"
  end

  def test_decompose_directive_sets_force_flag
    directive = AIA::ExecutionDirectives.new
    result = directive.decompose([], nil)

    assert_equal true, @config.instance_variable_get(:@force_decompose)
    assert_includes result, "Decomposition mode enabled"
  end

  # --- TrakFlow Directives ---

  def test_trakflow_directives_class_exists
    assert defined?(AIA::TrakFlowDirectives)
  end

  def test_tasks_returns_unavailable_when_no_client
    AIA.stubs(:client).returns(nil)
    directive = AIA::TrakFlowDirectives.new
    result = directive.tasks([], nil)

    assert_includes result, "TrakFlow not available"
  end

  def test_plan_returns_unavailable_when_no_client
    AIA.stubs(:client).returns(nil)
    directive = AIA::TrakFlowDirectives.new
    result = directive.plan([], nil)

    assert_includes result, "TrakFlow not available"
  end

  def test_plan_returns_usage_when_no_args
    robot = mock('robot')
    robot.stubs(:mcp_servers).returns([OpenStruct.new(name: "trak_flow")])
    AIA.stubs(:client).returns(robot)

    directive = AIA::TrakFlowDirectives.new
    result = directive.plan([], nil)

    assert_includes result, "Usage: /plan"
  end

  def test_task_returns_unavailable_when_no_client
    AIA.stubs(:client).returns(nil)
    directive = AIA::TrakFlowDirectives.new
    result = directive.task([], nil)

    assert_includes result, "TrakFlow not available"
  end

  def test_task_returns_usage_when_no_args
    robot = mock('robot')
    robot.stubs(:mcp_servers).returns([OpenStruct.new(name: "trak_flow")])
    AIA.stubs(:client).returns(robot)

    directive = AIA::TrakFlowDirectives.new
    result = directive.task([], nil)

    assert_includes result, "Usage: /task"
  end

  def test_tf_is_alias_for_tasks
    directive = AIA::TrakFlowDirectives.new
    assert directive.respond_to?(:tf)
  end
end
