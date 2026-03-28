# test/aia/directives/utility_directives_test.rb

require_relative '../../test_helper'
require 'ostruct'
require 'stringio'

class UtilityDirectivesTest < Minitest::Test
  def setup
    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output

    @test_config = OpenStruct.new(
      loaded_tools: [],
      flags: OpenStruct.new(debug: false)
    )
    AIA.stubs(:config).returns(@test_config)

    @instance = AIA::UtilityDirectives.new

    # TTY::Screen.width fails with StringIO, so stub it
    TTY::Screen.stubs(:width).returns(80)
  end

  def teardown
    $stdout = @original_stdout
    super
  end

  # --- /tools ---

  def test_tools_with_no_tools_loaded
    result = @instance.tools([])
    assert_equal '', result
    output = @captured_output.string
    assert_includes output, "No tools are available"
  end

  def test_tools_lists_loaded_tools
    mock_tool = mock('tool')
    mock_tool.stubs(:name).returns('calculator')
    mock_tool.stubs(:description).returns('A calculator tool for basic math')

    @test_config.loaded_tools = [mock_tool]

    result = @instance.tools([])
    assert_equal '', result
    output = @captured_output.string
    assert_includes output, "Available Tools"
    assert_includes output, "calculator"
    assert_includes output, "calculator tool"
  end

  def test_tools_filters_by_name
    tool_a = mock('tool_a')
    tool_a.stubs(:name).returns('calculator')
    tool_a.stubs(:description).returns('A calculator tool')

    tool_b = mock('tool_b')
    tool_b.stubs(:name).returns('web_search')
    tool_b.stubs(:description).returns('A web search tool')

    @test_config.loaded_tools = [tool_a, tool_b]

    result = @instance.tools(['calc'])
    output = @captured_output.string
    assert_includes output, "calculator"
    refute_includes output, "web_search"
  end

  def test_tools_filter_no_match
    mock_tool = mock('tool')
    mock_tool.stubs(:name).returns('calculator')
    mock_tool.stubs(:description).returns('A calculator tool')

    @test_config.loaded_tools = [mock_tool]

    @instance.tools(['nonexistent'])
    output = @captured_output.string
    assert_includes output, "No tools match the filter"
  end

  # --- /robot ---

  def test_robot_calls_utility_robot
    AIA::Utility.expects(:robot)
    result = @instance.robot([])
    assert_equal "", result
  end

  # --- /help ---

  def test_help_displays_directives
    result = @instance.help
    output = @captured_output.string
    assert_includes output, "Available Directives"
    assert_equal "", result
  end

  def test_help_shows_all_categories
    @instance.help
    output = @captured_output.string
    assert_includes output, "Configuration:"
    assert_includes output, "Context:"
    assert_includes output, "Execution:"
    assert_includes output, "Utility:"
  end

  def test_help_shows_directive_count
    @instance.help
    output = @captured_output.string
    assert_match(/Total: \d+ directives available/, output)
  end
end
