# frozen_string_literal: true
# test/aia/tool_filter_registry_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ToolFilterRegistryTest < Minitest::Test
  def setup
    @tools = []

    @base_flags = OpenStruct.new(
      tool_filter_a: false,
      tool_filter_load: false,
      tool_filter_save: false
    )

    @base_config = OpenStruct.new(
      flags: @base_flags,
      paths: OpenStruct.new(aia_dir: '/tmp/test_aia')
    )
  end

  def test_returns_empty_hash_when_no_flags_set
    result = AIA::ToolFilterRegistry.build_from_config(@base_config, @tools)

    assert_equal({}, result)
  end

  def test_builds_tfidf_filter_when_flag_set
    @base_flags.tool_filter_a = true

    tfidf_filter = mock('tfidf_filter')
    tfidf_filter.expects(:prep).once
    AIA::ToolFilter::TFIDF.expects(:new).with(has_entries(tools: @tools)).returns(tfidf_filter)

    result = AIA::ToolFilterRegistry.build_from_config(@base_config, @tools)

    assert_equal tfidf_filter, result[:tfidf]
  end

  def test_fact_asserter_instantiated_once_for_tfidf
    @base_flags.tool_filter_a = true

    fact_asserter_instances = []
    AIA::FactAsserter.stubs(:new).with { fact_asserter_instances << 1; true }.returns(mock('fa'))

    tfidf_filter = mock('tfidf_filter')
    tfidf_filter.stubs(:prep)
    AIA::ToolFilter::TFIDF.stubs(:new).returns(tfidf_filter)

    AIA::ToolFilterRegistry.build_from_config(@base_config, @tools)

    assert_equal 1, fact_asserter_instances.size,
      "FactAsserter should be instantiated exactly once for TF-IDF"
  end
end
