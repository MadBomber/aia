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

end
