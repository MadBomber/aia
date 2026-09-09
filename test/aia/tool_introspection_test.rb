# frozen_string_literal: true

# test/aia/tool_introspection_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ToolIntrospectionTest < Minitest::Test
  NamedTool = Struct.new(:name, :description)

  # Deliberately defines neither name nor description.
  BareTool = Class.new

  def test_tool_name_uses_name_method
    tool = NamedTool.new('search', 'Find things')
    assert_equal 'search', AIA::ToolIntrospection.tool_name(tool)
  end

  def test_tool_name_falls_back_to_class_name
    assert_equal 'ToolIntrospectionTest::BareTool',
                 AIA::ToolIntrospection.tool_name(ToolIntrospectionTest::BareTool.new)
  end

  def test_tool_description_stringifies
    tool = NamedTool.new('search', :symbolic)
    assert_equal 'symbolic', AIA::ToolIntrospection.tool_description(tool)
  end

  def test_tool_description_empty_when_unsupported
    assert_equal '', AIA::ToolIntrospection.tool_description(BareTool.new)
  end
end
