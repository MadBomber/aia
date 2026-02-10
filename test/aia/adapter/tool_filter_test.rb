# frozen_string_literal: true

require_relative '../../test_helper'

class ToolFilterTest < Minitest::Test
  def setup
    @tool_a = mock('tool_a')
    @tool_a.stubs(:name).returns('calculator')
    @tool_a.stubs(:class).returns(Class.new { def self.name; 'Calculator'; end })

    @tool_b = mock('tool_b')
    @tool_b.stubs(:name).returns('web_search')
    @tool_b.stubs(:class).returns(Class.new { def self.name; 'WebSearch'; end })

    @tool_c = mock('tool_c')
    @tool_c.stubs(:name).returns('file_reader')
    @tool_c.stubs(:class).returns(Class.new { def self.name; 'FileReader'; end })

    @all_tools = [@tool_a, @tool_b, @tool_c]
  end

  def teardown
    super
  end

  # --- filter_allowed ---

  def test_filter_allowed_returns_all_when_nil
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(allowed: nil)
    ))

    result = AIA::Adapter::ToolFilter.filter_allowed(@all_tools)
    assert_equal 3, result.size
  end

  def test_filter_allowed_returns_all_when_empty
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(allowed: [])
    ))

    result = AIA::Adapter::ToolFilter.filter_allowed(@all_tools)
    assert_equal 3, result.size
  end

  def test_filter_allowed_keeps_only_matching_tools
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(allowed: ['calculator'])
    ))

    result = AIA::Adapter::ToolFilter.filter_allowed(@all_tools)
    assert_equal 1, result.size
    assert_equal 'calculator', result.first.name
  end

  def test_filter_allowed_supports_partial_matching
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(allowed: ['search'])
    ))

    result = AIA::Adapter::ToolFilter.filter_allowed(@all_tools)
    assert_equal 1, result.size
    assert_equal 'web_search', result.first.name
  end

  def test_filter_allowed_with_multiple_patterns
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(allowed: ['calculator', 'file'])
    ))

    result = AIA::Adapter::ToolFilter.filter_allowed(@all_tools)
    assert_equal 2, result.size
    names = result.map(&:name)
    assert_includes names, 'calculator'
    assert_includes names, 'file_reader'
  end

  def test_filter_allowed_returns_empty_when_none_match
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(allowed: ['nonexistent'])
    ))

    result = AIA::Adapter::ToolFilter.filter_allowed(@all_tools)
    assert_empty result
  end

  # --- filter_rejected ---

  def test_filter_rejected_returns_all_when_nil
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(rejected: nil)
    ))

    result = AIA::Adapter::ToolFilter.filter_rejected(@all_tools)
    assert_equal 3, result.size
  end

  def test_filter_rejected_returns_all_when_empty
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(rejected: [])
    ))

    result = AIA::Adapter::ToolFilter.filter_rejected(@all_tools)
    assert_equal 3, result.size
  end

  def test_filter_rejected_removes_matching_tools
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(rejected: ['calculator'])
    ))

    result = AIA::Adapter::ToolFilter.filter_rejected(@all_tools)
    assert_equal 2, result.size
    names = result.map(&:name)
    refute_includes names, 'calculator'
  end

  def test_filter_rejected_supports_partial_matching
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(rejected: ['file'])
    ))

    result = AIA::Adapter::ToolFilter.filter_rejected(@all_tools)
    assert_equal 2, result.size
    refute result.any? { |t| t.name == 'file_reader' }
  end

  def test_filter_rejected_with_multiple_patterns
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(rejected: ['calculator', 'web'])
    ))

    result = AIA::Adapter::ToolFilter.filter_rejected(@all_tools)
    assert_equal 1, result.size
    assert_equal 'file_reader', result.first.name
  end

  # --- drop_duplicates ---

  def test_drop_duplicates_removes_dupes
    dup_tool = mock('dup_tool')
    dup_tool.stubs(:name).returns('calculator')

    tools = [@tool_a, @tool_b, dup_tool]

    result = AIA::Adapter::ToolFilter.drop_duplicates(tools)
    assert_equal 2, result.size
    assert_equal ['calculator', 'web_search'], result.map(&:name)
  end

  def test_drop_duplicates_keeps_first_occurrence
    first = mock('first')
    first.stubs(:name).returns('my_tool')

    second = mock('second')
    second.stubs(:name).returns('my_tool')

    result = AIA::Adapter::ToolFilter.drop_duplicates([first, second])
    assert_equal 1, result.size
    assert_same first, result.first
  end

  def test_drop_duplicates_no_dupes
    result = AIA::Adapter::ToolFilter.drop_duplicates(@all_tools)
    assert_equal 3, result.size
  end

  def test_drop_duplicates_empty_array
    result = AIA::Adapter::ToolFilter.drop_duplicates([])
    assert_empty result
  end

  def test_drop_duplicates_logs_warning_on_duplicates
    dup_tool = mock('dup_tool')
    dup_tool.stubs(:name).returns('calculator')

    tools = [@tool_a, dup_tool]

    capture_io do
      AIA::Adapter::ToolFilter.drop_duplicates(tools)
    end

    # Check the logger recorded the duplicate warning
    entries = AIA::LoggerManager.test_entries(:aia)
    assert entries.any? { |e| e.message.to_s.include?('Duplicate tool detected') },
           "Expected logger to record duplicate tool warning"
  end
end
