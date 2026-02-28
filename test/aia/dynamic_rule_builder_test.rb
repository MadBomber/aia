# frozen_string_literal: true
# test/aia/dynamic_rule_builder_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class DynamicRuleBuilderTest < Minitest::Test
  def setup
    @config = create_test_config
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:user_rules).returns(Hash.new { |h, k| h[k] = [] })
    @decisions = AIA::Decisions.new
    @fact_asserter = AIA::FactAsserter.new
  end

  # =========================================================================
  # Constants
  # =========================================================================

  def test_tool_domain_patterns_constant_is_frozen
    assert AIA::DynamicRuleBuilder::TOOL_DOMAIN_PATTERNS.frozen?
  end

  def test_builtin_classify_domains_constant_is_frozen
    assert AIA::DynamicRuleBuilder::BUILTIN_CLASSIFY_DOMAINS.frozen?
  end

  # =========================================================================
  # map_tools_to_domains
  # =========================================================================

  def test_map_tools_to_domains_classifies_database_tool_as_data
    db_tool = make_tool("my_database", "Executes SQL queries on the database")

    result = AIA::DynamicRuleBuilder.map_tools_to_domains([db_tool], @fact_asserter)

    assert_includes result["data"], "my_database"
  end

  def test_map_tools_to_domains_classifies_code_tool
    code_tool = make_tool("eval_tool", "Execute code in Ruby, Python, Shell")

    result = AIA::DynamicRuleBuilder.map_tools_to_domains([code_tool], @fact_asserter)

    assert_includes result["code"], "eval_tool"
  end

  def test_map_tools_to_domains_file_tools_also_in_code_domain
    file_tool = make_tool("disk_reader", "Read and write files on disk")

    result = AIA::DynamicRuleBuilder.map_tools_to_domains([file_tool], @fact_asserter)

    assert_includes result["file"], "disk_reader"
    assert_includes result["code"], "disk_reader",
      "File tools should also be available for code domain"
  end

  def test_map_tools_to_domains_no_match_returns_empty
    generic_tool = make_tool("clipboard", "Copy and paste text")

    result = AIA::DynamicRuleBuilder.map_tools_to_domains([generic_tool], @fact_asserter)

    assert_empty result, "Tool with no domain match should not appear in any domain"
  end

  # =========================================================================
  # map_tools_to_mcp_servers
  # =========================================================================

  def test_map_tools_to_mcp_servers_groups_by_server
    tool1 = make_tool("tool_a", "does things")
    tool1.define_singleton_method(:mcp) { "my_server" }

    tool2 = make_tool("tool_b", "does other things")
    tool2.define_singleton_method(:mcp) { "my_server" }

    result = AIA::DynamicRuleBuilder.map_tools_to_mcp_servers([tool1, tool2], @fact_asserter)

    assert_equal ["tool_a", "tool_b"], result["my_server"]
  end

  def test_map_tools_to_mcp_servers_skips_non_mcp_tools
    tool = make_tool("local_tool", "a local tool")

    result = AIA::DynamicRuleBuilder.map_tools_to_mcp_servers([tool], @fact_asserter)

    assert_empty result, "Non-MCP tools should be skipped"
  end

  # =========================================================================
  # register (orchestrator)
  # =========================================================================

  def test_register_returns_domain_and_server_mappings
    kbs = AIA::KBDefinitions.build_all_kbs(@decisions)
    db_tool = make_tool("database_tool", "Executes SQL commands on a database")

    result = AIA::DynamicRuleBuilder.register(kbs, @decisions, @fact_asserter, [db_tool])

    assert_instance_of Hash, result
    assert result.key?(:domain_tools), "Result must include :domain_tools"
    assert result.key?(:server_tools), "Result must include :server_tools"
    assert_includes result[:domain_tools]["data"], "database_tool"
  end

  private

  def make_tool(name, description)
    tool = Class.new
    tool.define_singleton_method(:name) { name }
    tool.define_singleton_method(:description) { description }
    tool
  end

  def create_test_config
    OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      pipeline: [],
      context_files: [],
      mcp_servers: [],
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
end
