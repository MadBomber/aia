# frozen_string_literal: true
# test/aia/tool_filter_registry_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ToolFilterRegistryTest < Minitest::Test
  def setup
    @rule_router = mock('rule_router')
    @tools = []

    @base_flags = OpenStruct.new(
      tool_filter_a: false,
      tool_filter_b: false,
      tool_filter_c: false,
      tool_filter_d: false,
      tool_filter_e: false,
      tool_filter_load: false,
      tool_filter_save: false
    )

    @base_config = OpenStruct.new(
      flags: @base_flags,
      paths: OpenStruct.new(aia_dir: '/tmp/test_aia')
    )
  end

  def test_returns_empty_hash_when_no_flags_set
    @rule_router.expects(:register_tools)
                .with(@tools, db_dir: '/tmp/test_aia', load_db: false, save_db: false)

    result = AIA::ToolFilterRegistry.build_from_config(@base_config, @tools, rule_router: @rule_router)

    assert_equal({}, result)
  end

  def test_registers_tools_with_rule_router_when_kbs_filter_off
    @rule_router.expects(:register_tools)
                .with(@tools, db_dir: '/tmp/test_aia', load_db: false, save_db: false)
                .once

    AIA::ToolFilterRegistry.build_from_config(@base_config, @tools, rule_router: @rule_router)
  end

  def test_builds_kbs_filter_when_flag_set
    @base_flags.tool_filter_a = true

    kbs_filter = mock('kbs_filter')
    kbs_filter.expects(:prep).once
    AIA::ToolFilter::KBS.expects(:new).with(
      rule_router: @rule_router, tools: @tools,
      db_dir: '/tmp/test_aia', load_db: false, save_db: false
    ).returns(kbs_filter)

    result = AIA::ToolFilterRegistry.build_from_config(@base_config, @tools, rule_router: @rule_router)

    assert_equal kbs_filter, result[:kbs]
    refute result.key?(:tfidf)
  end

  def test_does_not_register_tools_when_kbs_filter_is_on
    @base_flags.tool_filter_a = true

    kbs_filter = mock('kbs_filter')
    kbs_filter.stubs(:prep)
    AIA::ToolFilter::KBS.stubs(:new).returns(kbs_filter)

    @rule_router.expects(:register_tools).never

    AIA::ToolFilterRegistry.build_from_config(@base_config, @tools, rule_router: @rule_router)
  end

  def test_builds_tfidf_filter_when_flag_set
    @base_flags.tool_filter_b = true
    @rule_router.stubs(:register_tools)

    tfidf_filter = mock('tfidf_filter')
    tfidf_filter.expects(:prep).once
    AIA::ToolFilter::TFIDF.expects(:new).with(has_entries(tools: @tools)).returns(tfidf_filter)

    result = AIA::ToolFilterRegistry.build_from_config(@base_config, @tools, rule_router: @rule_router)

    assert_equal tfidf_filter, result[:tfidf]
  end

  def test_multiple_filters_can_be_active_simultaneously
    @base_flags.tool_filter_b = true
    @base_flags.tool_filter_e = true
    @rule_router.stubs(:register_tools)

    tfidf_filter = mock('tfidf_filter')
    tfidf_filter.stubs(:prep)
    AIA::ToolFilter::TFIDF.stubs(:new).returns(tfidf_filter)

    lsi_filter = mock('lsi_filter')
    lsi_filter.stubs(:prep)
    AIA::ToolFilter::LSI.stubs(:new).returns(lsi_filter)

    result = AIA::ToolFilterRegistry.build_from_config(@base_config, @tools, rule_router: @rule_router)

    assert result.key?(:tfidf)
    assert result.key?(:lsi)
    refute result.key?(:kbs)
  end

  def test_shared_fact_asserter_across_b_c_d_e
    @base_flags.tool_filter_b = true
    @base_flags.tool_filter_e = true
    @rule_router.stubs(:register_tools)

    fact_asserter_instances = []
    AIA::FactAsserter.stubs(:new).with { fact_asserter_instances << 1; true }.returns(mock('fa'))

    tfidf_filter = mock('tfidf_filter')
    tfidf_filter.stubs(:prep)
    AIA::ToolFilter::TFIDF.stubs(:new).returns(tfidf_filter)

    lsi_filter = mock('lsi_filter')
    lsi_filter.stubs(:prep)
    AIA::ToolFilter::LSI.stubs(:new).returns(lsi_filter)

    AIA::ToolFilterRegistry.build_from_config(@base_config, @tools, rule_router: @rule_router)

    assert_equal 1, fact_asserter_instances.size,
      "FactAsserter should be instantiated only once even when multiple filters are active"
  end
end
