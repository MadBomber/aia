# frozen_string_literal: true
# test/aia/fact_asserter_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class FactAsserterTest < Minitest::Test
  def setup
    @asserter = AIA::FactAsserter.new
    @kb = MockKB.new
    @config = create_test_config
  end

  # =========================================================================
  # assert_facts_for — dispatcher routing
  # =========================================================================

  def test_assert_facts_for_classify_asserts_context_and_turn
    temp_file = create_temp_file("test.rb", "class Foo; end")
    @config.context_files = [temp_file]

    @asserter.assert_facts_for(@kb, :classify, @config, "refactor this")

    assert @kb.asserted?(:context_file), "Expected :context_file fact"
    assert @kb.asserted?(:turn_input), "Expected :turn_input fact"
  ensure
    cleanup_temp_file(temp_file)
  end

  def test_assert_facts_for_classify_without_input_skips_turn
    @config.context_files = []

    @asserter.assert_facts_for(@kb, :classify, @config, nil)

    refute @kb.asserted?(:turn_input), "Should not assert turn_input when input is nil"
  end

  def test_assert_facts_for_model_select_asserts_model_facts
    @asserter.assert_facts_for(@kb, :model_select, @config, nil)

    assert @kb.asserted?(:model), "Expected :model fact"
  end

  def test_assert_model_facts_does_not_raise_when_models_is_nil
    @config.models = nil

    @asserter.assert_facts_for(@kb, :model_select, @config, nil)
    # No assertion needed — test passes if no exception raised
  end

  def test_assert_facts_for_route_asserts_mcp_tool_and_turn
    @config.loaded_tools = []
    AIA.stubs(:client).returns(nil)

    @asserter.assert_facts_for(@kb, :route, @config, "query the database")

    assert @kb.asserted?(:turn_input), "Expected :turn_input fact"
  end

  def test_assert_facts_for_gate_asserts_context_stats_turn_session
    @config.context_files = []
    tracker = mock('tracker')
    tracker.stubs(:to_facts).returns({ total_cost: 0.5, turn_count: 3 })
    AIA.stubs(:session_tracker).returns(tracker)

    @asserter.assert_facts_for(@kb, :gate, @config, "test input")

    assert @kb.asserted?(:context_stats), "Expected :context_stats fact"
    assert @kb.asserted?(:turn_input), "Expected :turn_input fact"
    assert @kb.asserted?(:session_stats), "Expected :session_stats fact"
  end

  # =========================================================================
  # assert_context_facts
  # =========================================================================

  def test_assert_context_facts_with_files
    temp_file = create_temp_file("code.rb", "puts 'hello'")
    @config.context_files = [temp_file]

    @asserter.send(:assert_context_facts, @kb, @config)

    fact = @kb.facts_for(:context_file).first
    assert_equal temp_file, fact[:path]
    assert_equal ".rb", fact[:extension]
    assert_equal true, fact[:exists]
  ensure
    cleanup_temp_file(temp_file)
  end

  def test_assert_context_facts_with_nonexistent_file
    @config.context_files = ["/nonexistent/path.txt"]

    @asserter.send(:assert_context_facts, @kb, @config)

    fact = @kb.facts_for(:context_file).first
    assert_equal false, fact[:exists]
    assert_equal ".txt", fact[:extension]
  end

  def test_assert_context_facts_with_empty_files
    @config.context_files = []

    @asserter.send(:assert_context_facts, @kb, @config)

    assert_empty @kb.facts_for(:context_file)
  end

  # =========================================================================
  # assert_context_stats
  # =========================================================================

  def test_assert_context_stats_calculates_total_size
    temp_file = create_temp_file("stats.txt", "x" * 500)
    @config.context_files = [temp_file]

    @asserter.send(:assert_context_stats, @kb, @config)

    fact = @kb.facts_for(:context_stats).first
    assert_equal 500, fact[:total_size]
    assert_equal false, fact[:large]
  ensure
    cleanup_temp_file(temp_file)
  end

  def test_assert_context_stats_flags_large_context
    temp_file = create_temp_file("large.txt", "x" * 200_000)
    @config.context_files = [temp_file]

    @asserter.send(:assert_context_stats, @kb, @config)

    fact = @kb.facts_for(:context_stats).first
    assert_equal true, fact[:large]
    assert fact[:total_size] > 100_000
  ensure
    cleanup_temp_file(temp_file)
  end

  def test_assert_context_stats_handles_missing_files
    @config.context_files = ["/nonexistent/file.txt"]

    @asserter.send(:assert_context_stats, @kb, @config)

    fact = @kb.facts_for(:context_stats).first
    assert_equal 0, fact[:total_size]
    assert_equal false, fact[:large]
  end

  # =========================================================================
  # assert_model_facts
  # =========================================================================

  def test_assert_model_facts_without_rubyllm
    @asserter.send(:assert_model_facts, @kb, @config)

    fact = @kb.facts_for(:model).first
    assert_equal "gpt-4o-mini", fact[:name]
    assert_nil fact[:role]
  end

  def test_assert_model_facts_with_model_info
    model_info = OpenStruct.new(
      provider: "openai",
      context_window: 128_000,
      input_price_per_million: 0.15
    )
    model_info.define_singleton_method(:supports?) { |cap| cap == :vision }

    @asserter.stubs(:find_model_info).returns(model_info)

    @asserter.send(:assert_model_facts, @kb, @config)

    fact = @kb.facts_for(:model).first
    assert_equal "gpt-4o-mini", fact[:name]
    assert_equal "openai", fact[:provider]
    assert_equal 128_000, fact[:context_window]
    assert_equal true, fact[:supports_vision]
    assert_equal false, fact[:supports_audio]
    assert_equal "low", fact[:cost_tier]
  end

  # =========================================================================
  # assert_mcp_facts
  # =========================================================================

  def test_assert_mcp_facts_with_servers
    @config.mcp_servers = [
      { name: "code-server", topics: ["code", "files"] }
    ]

    @asserter.send(:assert_mcp_facts, @kb, @config)

    fact = @kb.facts_for(:mcp_server).first
    assert_equal "code-server", fact[:name]
    assert_equal ["code", "files"], fact[:topics]
    assert_equal true, fact[:active]
  end

  def test_assert_mcp_facts_skips_when_no_mcp_flag
    @config.flags.no_mcp = true
    @config.mcp_servers = [{ name: "server", topics: [] }]

    @asserter.send(:assert_mcp_facts, @kb, @config)

    assert_empty @kb.facts_for(:mcp_server)
  end

  def test_assert_mcp_facts_with_string_keys
    @config.mcp_servers = [
      { "name" => "string-server", "topics" => ["data"] }
    ]

    @asserter.send(:assert_mcp_facts, @kb, @config)

    fact = @kb.facts_for(:mcp_server).first
    assert_equal "string-server", fact[:name]
  end

  # =========================================================================
  # assert_tool_facts
  # =========================================================================

  def test_assert_tool_facts_with_local_tools
    tool = Class.new
    tool.define_singleton_method(:name) { "my_tool" }
    tool.define_singleton_method(:description) { "A test tool" }
    @config.loaded_tools = [tool]
    AIA.stubs(:client).returns(nil)

    @asserter.send(:assert_tool_facts, @kb, @config)

    fact = @kb.facts_for(:tool).first
    assert_equal "my_tool", fact[:name]
    assert_equal "A test tool", fact[:description]
    assert_equal true, fact[:active]
  end

  def test_assert_tool_facts_includes_mcp_tools
    local_tool = Class.new
    local_tool.define_singleton_method(:name) { "local" }
    local_tool.define_singleton_method(:description) { "local tool" }
    @config.loaded_tools = [local_tool]

    mcp_tool = Class.new
    mcp_tool.define_singleton_method(:name) { "mcp_tool" }
    mcp_tool.define_singleton_method(:description) { "remote tool" }

    robot = mock('robot')
    robot.stubs(:respond_to?).with(:mcp_tools).returns(true)
    robot.stubs(:mcp_tools).returns([mcp_tool])
    AIA.stubs(:client).returns(robot)

    @asserter.send(:assert_tool_facts, @kb, @config)

    names = @kb.facts_for(:tool).map { |f| f[:name] }
    assert_includes names, "local"
    assert_includes names, "mcp_tool"
  end

  # =========================================================================
  # assert_turn_facts
  # =========================================================================

  def test_assert_turn_facts
    @asserter.send(:assert_turn_facts, @kb, "hello world")

    fact = @kb.facts_for(:turn_input).first
    assert_equal "hello world", fact[:text]
    assert_equal 11, fact[:length]
  end

  def test_turn_input_fact_includes_keywords_set
    @config.loaded_tools = []
    AIA.stubs(:client).returns(nil)

    @asserter.assert_facts_for(@kb, :route, @config, "tell me about the computer system")

    facts = @kb.facts_for(:turn_input)
    assert_equal 1, facts.size
    turn = facts.first
    assert turn.key?(:keywords), "Expected :keywords key in turn_input fact"
    assert_instance_of Set, turn[:keywords], "Expected keywords to be a Set"
    assert_includes turn[:keywords], "computer"
    assert_includes turn[:keywords], "system"
  end

  # =========================================================================
  # assert_session_facts
  # =========================================================================

  def test_assert_session_facts_with_tracker
    tracker = mock('tracker')
    tracker.stubs(:to_facts).returns({ total_cost: 1.5, turn_count: 5 })
    AIA.stubs(:session_tracker).returns(tracker)

    @asserter.send(:assert_session_facts, @kb)

    fact = @kb.facts_for(:session_stats).first
    assert_equal 1.5, fact[:total_cost]
    assert_equal 5, fact[:turn_count]
  end

  def test_assert_session_facts_without_tracker
    AIA.stubs(:session_tracker).returns(nil)

    @asserter.send(:assert_session_facts, @kb)

    assert_empty @kb.facts_for(:session_stats)
  end

  # =========================================================================
  # assert_response_facts
  # =========================================================================

  def test_assert_response_facts_with_outcome
    AIA.stubs(:session_tracker).returns(nil)

    outcome = { accepted: true, model: "gpt-4o-mini" }
    @asserter.assert_response_facts(@kb, outcome)

    fact = @kb.facts_for(:response_outcome).first
    assert_equal true, fact[:accepted]
    assert_equal "gpt-4o-mini", fact[:model]
  end

  def test_assert_response_facts_with_empty_outcome
    AIA.stubs(:session_tracker).returns(nil)

    @asserter.assert_response_facts(@kb, {})

    assert_empty @kb.facts_for(:response_outcome)
  end

  def test_assert_response_facts_includes_session_stats
    tracker = mock('tracker')
    tracker.stubs(:to_facts).returns({ total_cost: 2.0 })
    AIA.stubs(:session_tracker).returns(tracker)

    @asserter.assert_response_facts(@kb, { accepted: true })

    assert @kb.asserted?(:session_stats), "Expected session_stats fact"
  end

  # =========================================================================
  # assert_decision_facts
  # =========================================================================

  def test_assert_decision_facts_for_model_select
    decisions = AIA::Decisions.new
    decisions.add(:classification, domain: "code", source: "code_request")

    @asserter.assert_decision_facts(@kb, :model_select, decisions)

    fact = @kb.facts_for(:classification_decision).first
    assert_equal "code", fact[:domain]
  end

  def test_assert_decision_facts_for_route
    decisions = AIA::Decisions.new
    decisions.add(:classification, domain: "data", source: "data_request")
    decisions.add(:model_decision, model: "gpt-4o", reason: "test")

    @asserter.assert_decision_facts(@kb, :route, decisions)

    assert @kb.asserted?(:classification_decision)
    assert @kb.asserted?(:model_decision_upstream)
  end

  def test_assert_decision_facts_for_gate
    decisions = AIA::Decisions.new
    decisions.add(:model_decision, model: "gpt-4o", reason: "test")

    @asserter.assert_decision_facts(@kb, :gate, decisions)

    assert @kb.asserted?(:model_decision)
  end

  def test_assert_decision_facts_for_classify_does_nothing
    decisions = AIA::Decisions.new
    decisions.add(:classification, domain: "code")

    @asserter.assert_decision_facts(@kb, :classify, decisions)

    assert_empty @kb.all_facts
  end

  # =========================================================================
  # classify_cost
  # =========================================================================

  def test_classify_cost_low
    info = OpenStruct.new(input_price_per_million: 0.5)
    assert_equal "low", @asserter.send(:classify_cost, info)
  end

  def test_classify_cost_medium
    info = OpenStruct.new(input_price_per_million: 5.0)
    assert_equal "medium", @asserter.send(:classify_cost, info)
  end

  def test_classify_cost_high
    info = OpenStruct.new(input_price_per_million: 30.0)
    assert_equal "high", @asserter.send(:classify_cost, info)
  end

  def test_classify_cost_premium
    info = OpenStruct.new(input_price_per_million: 100.0)
    assert_equal "premium", @asserter.send(:classify_cost, info)
  end

  def test_classify_cost_nil_price
    info = OpenStruct.new(input_price_per_million: nil)
    assert_equal "low", @asserter.send(:classify_cost, info)
  end

  def test_classify_cost_no_method
    info = Object.new
    assert_equal "low", @asserter.send(:classify_cost, info)
  end

  # =========================================================================
  # tool_name / tool_description (public helpers)
  # =========================================================================

  def test_tool_name_with_name_method
    tool = Class.new
    tool.define_singleton_method(:name) { "my_tool" }

    assert_equal "my_tool", @asserter.tool_name(tool)
  end

  def test_tool_name_without_name_method
    tool = Object.new

    assert_equal tool.to_s, @asserter.tool_name(tool)
  end

  def test_tool_description_with_description_method
    tool = Class.new
    tool.define_singleton_method(:description) { "Does things" }

    assert_equal "Does things", @asserter.tool_description(tool)
  end

  def test_tool_description_without_description_method
    tool = Object.new

    assert_equal "", @asserter.tool_description(tool)
  end

  def test_tool_description_handles_exception
    tool = Class.new
    tool.define_singleton_method(:description) { raise "boom" }

    assert_equal "", @asserter.tool_description(tool)
  end

  # =========================================================================
  # Stateless verification
  # =========================================================================

  def test_fact_asserter_has_no_instance_variables
    asserter = AIA::FactAsserter.new
    assert_empty asserter.instance_variables,
      "FactAsserter should be stateless (no instance variables)"
  end

  private

  def create_test_config
    OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      pipeline: [],
      context_files: [],
      mcp_servers: [],
      loaded_tools: [],
      flags: OpenStruct.new(
        chat: false,
        debug: false,
        verbose: false,
        consensus: false,
        no_mcp: false
      ),
      rules: OpenStruct.new(
        dir: nil,
        enabled: false
      )
    )
  end

  def create_temp_file(name, content)
    path = File.join(Dir.tmpdir, "fact_asserter_test_#{$$}_#{name}")
    File.write(path, content)
    path
  end

  def cleanup_temp_file(path)
    File.delete(path) if path && File.exist?(path)
  end

  # =========================================================================
  # Mock KB — records assert calls for verification
  # =========================================================================

  class MockKB
    def initialize
      @facts = Hash.new { |h, k| h[k] = [] }
    end

    def assert(type, **attrs)
      @facts[type] << attrs
    end

    def asserted?(type)
      @facts.key?(type) && @facts[type].any?
    end

    def facts_for(type)
      @facts[type]
    end

    def all_facts
      @facts
    end
  end
end
