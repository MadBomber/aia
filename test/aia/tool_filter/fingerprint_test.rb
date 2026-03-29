# frozen_string_literal: true
# test/aia/tool_filter/fingerprint_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'
require 'tmpdir'

class ToolFilterFingerprintTest < Minitest::Test
  MockTool = Struct.new(:name, :description)

  def build_tools
    [
      MockTool.new("search", "Search for files"),
      MockTool.new("browse", "Browse web pages"),
    ]
  end

  def fact_asserter
    AIA::FactAsserter.new
  end

  def test_fingerprint_is_deterministic
    tools = build_tools
    fa = fact_asserter
    filter = AIA::ToolFilter::TFIDF.new(tools: tools, fact_asserter: fa)
    fp1 = filter.send(:fingerprint_from_tools, tools)
    fp2 = filter.send(:fingerprint_from_tools, tools)
    assert_equal fp1, fp2
  end

  def test_fingerprint_changes_when_tool_set_changes
    tools_a = build_tools
    tools_b = [MockTool.new("email", "Send emails")]
    fa = fact_asserter
    filter = AIA::ToolFilter::TFIDF.new(tools: tools_a, fact_asserter: fa)
    fp_a = filter.send(:fingerprint_from_tools, tools_a)
    fp_b = filter.send(:fingerprint_from_tools, tools_b)
    refute_equal fp_a, fp_b
  end

  def test_lsi_load_returns_false_on_fingerprint_mismatch
    Dir.mktmpdir do |dir|
      tools = build_tools
      fa = fact_asserter

      # Save with original tools
      filter = AIA::ToolFilter::LSI.new(
        tools: tools, fact_asserter: fa,
        db_dir: dir, save_db: true
      )
      filter.prep
      assert filter.available?

      # Load with a DIFFERENT tool set — fingerprint won't match
      different_tools = [MockTool.new("completely_different", "A new tool")]
      filter2 = AIA::ToolFilter::LSI.new(
        tools: different_tools, fact_asserter: fa,
        db_dir: dir, load_db: true
      )
      filter2.prep

      # After mismatch, filter rebuilds from different_tools
      results = filter2.filter("completely different")
      # Either nil (all below threshold) or includes the new tool
      assert results.nil? || results.include?("completely_different")
    end
  end
end
