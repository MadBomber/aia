require_relative '../test_helper'
require 'ostruct'
require 'stringio'
require_relative '../../lib/aia'

class UtilityTest < Minitest::Test
  def setup
    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output
    
    # Mock AIA.config with comprehensive test data
    AIA.stubs(:config).returns(OpenStruct.new(
      model: 'claude-3-sonnet',
      adapter: 'anthropic',
      last_refresh: '2024-01-15',
      tool_paths: [],
      tools: 'calculator, weather_api, file_reader'
    ))
    
    # Mock TTY::Screen.width
    TTY::Screen.stubs(:width).returns(100)
    
    # Mock AIA::VERSION
    AIA.stubs(:const_get).with(:VERSION).returns('0.9.9')
    
    # Mock RubyLLM::VERSION  
    RubyLLM.stubs(:const_get).with(:VERSION).returns('1.3.1')
  end

  def teardown
    $stdout = @original_stdout
  end

  def test_robot_displays_ascii_art
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Check for ASCII art elements
    assert_includes output, "(\\____/)"
    assert_includes output, "(_oo_)"
    assert_includes output, "(O)"
    assert_includes output, "__||__"
    assert_includes output, "[/______\\]"
    assert_includes output, "/ \\__AI__/ \\/"
    assert_includes output, "/    /__\\"
    assert_includes output, "(\\   /____\\"
  end

  def test_robot_displays_version_information
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Check for version information
    assert_includes output, "AI Assistant (v0.9.9) is Online"
    assert_includes output, "using anthropic (v1.3.1)"
  end

  def test_robot_displays_model_information
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Check for model information
    assert_includes output, "claude-3-sonnet"
  end

  def test_robot_displays_last_refresh_date
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Check for last refresh information
    assert_includes output, "model db was last refreshed on"
    assert_includes output, "2024-01-15"
  end

  def test_robot_with_empty_tool_paths
    AIA.config.tool_paths = []
    
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Should show message about sharing tools
    assert_includes output, "You can share my tools"
    refute_includes output, "I will also use your tools"
    refute_includes output, "My Toolbox contains:"
  end

  def test_robot_with_non_empty_tool_paths
    AIA.config.tool_paths = ['/path/to/tools']
    
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Should show message about using user's tools
    assert_includes output, "I will also use your tools"
    assert_includes output, "My Toolbox contains:"
    refute_includes output, "You can share my tools"
  end

  def test_robot_displays_tools_when_available
    # Mock WordWrapper
    mock_wrapper = mock('wrapper')
    mock_wrapper.expects(:wrap).returns("calculator, weather_api,\nfile_reader")
    WordWrapper::MinimumRaggedness.expects(:new).with(80, 'calculator, weather_api, file_reader').returns(mock_wrapper)
    
    AIA.config.tools = 'calculator, weather_api, file_reader'
    AIA.config.tool_paths = ['/some/path']  # Non-empty to trigger toolbox display
    
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Should include wrapped tools text
    assert_includes output, "calculator, weather_api,"
    assert_includes output, "file_reader"
  end

  def test_robot_handles_nil_tools
    AIA.config.tools = nil
    
    # Should not raise an error
    AIA::Utility.robot
    # If we get here without an exception, the test passes
    
    output = @captured_output.string
    assert_includes output, "AI Assistant"  # Should still display basic info
  end

  def test_robot_calculates_correct_width
    TTY::Screen.stubs(:width).returns(120)
    
    # Mock WordWrapper to verify correct width calculation
    expected_width = 120 - 18 - 2  # total_width - indent - margin = 100
    mock_wrapper = mock('wrapper')
    mock_wrapper.expects(:wrap).returns("tools")
    WordWrapper::MinimumRaggedness.expects(:new).with(expected_width, anything).returns(mock_wrapper)
    
    AIA.config.tools = 'some tools'
    AIA.config.tool_paths = ['/path']
    
    AIA::Utility.robot
  end

  def test_robot_applies_correct_indentation
    # Mock WordWrapper to return multi-line text
    mock_wrapper = mock('wrapper')
    mock_wrapper.expects(:wrap).returns("line1\nline2\nline3")
    WordWrapper::MinimumRaggedness.expects(:new).returns(mock_wrapper)
    
    AIA.config.tools = 'test tools'
    AIA.config.tool_paths = ['/path']
    
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Each line should be indented with 18 spaces
    lines = output.split("\n")
    tool_lines = lines.select { |line| line.start_with?(' ' * 18) && line.include?('line') }
    
    assert tool_lines.size >= 3, "Should have at least 3 indented tool lines"
  end

  def test_robot_class_method_accessibility
    # Verify that robot is accessible as a class method
    assert_respond_to AIA::Utility, :robot
    
    # Verify it's defined as a class method (not instance method)
    refute_respond_to AIA::Utility.new, :robot
  end

  def test_robot_with_edge_case_screen_widths
    # Test with very narrow screen
    TTY::Screen.stubs(:width).returns(25)
    
    # Should handle narrow width gracefully
    AIA::Utility.robot
    # If we get here without an exception, the test passes
    
    output = @captured_output.string
    assert_includes output, "AI Assistant"
  end

  def test_robot_string_interpolation
    # Test that all string interpolations work correctly
    # Save original constants
    original_aia_version = AIA::VERSION
    original_rubyllm_version = RubyLLM::VERSION
    
    # Temporarily override constants
    AIA.const_set(:VERSION, 'test-version')
    RubyLLM.const_set(:VERSION, 'test-ruby-llm')
    
    AIA.config.model = 'test-model'
    AIA.config.adapter = 'test-adapter'
    AIA.config.last_refresh = '2024-test-date'
    
    AIA::Utility.robot
    
    output = @captured_output.string
    
    assert_includes output, "test-version"
    assert_includes output, "test-ruby-llm"
    assert_includes output, "test-model"
    assert_includes output, "test-adapter"
    assert_includes output, "2024-test-date"
  ensure
    # Restore original constants
    AIA.const_set(:VERSION, original_aia_version)
    RubyLLM.const_set(:VERSION, original_rubyllm_version)
  end
end