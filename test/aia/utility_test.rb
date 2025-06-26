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
    # Save original constants and config values
    original_aia_version     = AIA::VERSION
    original_rubyllm_version = RubyLLM::VERSION
    original_model           = AIA.config.model

    # Override for test
    AIA.const_set(:VERSION, 'vX.Y.Z')
    RubyLLM.const_set(:VERSION, 'vR.L.M')
    AIA.config.model = 'my-test-model'

    AIA::Utility.robot
    output = @captured_output.string

    # Validate interpolated versions and model
    assert_includes output, "AI Assistant (vvX.Y.Z)"
    assert_includes output, "using anthropic (vvR.L.M)"
    assert_includes output, 'my-test-model'

    # Restore originals
    AIA.const_set(:VERSION, original_aia_version)
    RubyLLM.const_set(:VERSION, original_rubyllm_version)
    AIA.config.model = original_model
  end

  def test_robot_with_empty_tools_string
    AIA.config.tools = ''
    AIA.config.tool_paths = ['/path']
    
    # Should not raise an error with empty tools string
    AIA::Utility.robot
    
    output = @captured_output.string
    assert_includes output, "AI Assistant"
  end
  
  def test_robot_executes_all_code_paths_with_tools
    # This test specifically targets the missed lines by ensuring real execution
    # Clear existing stubs and create fresh config
    
    # Clear the existing stub and create a real config object with tools to trigger the missed lines
    AIA.unstub(:config)
    real_config = OpenStruct.new(
      model: 'gpt-4-turbo',
      adapter: 'openai', 
      last_refresh: '2024-12-26',
      tool_paths: ['/usr/local/tools', '/home/tools'],  # Non-empty to trigger lines 24, 26
      tools: 'calculator, weather_api, file_reader'           # Non-nil to trigger lines 28, 29
    )
    
    # Temporarily replace the config
    original_config_method = AIA.method(:config) rescue nil
    AIA.define_singleton_method(:config) { real_config }
    
    # Mock only what's absolutely necessary to avoid external dependencies
    TTY::Screen.expects(:width).returns(100).at_least_once  # This will trigger width calculation on line 14
    
    # Mock WordWrapper to avoid complexity but still trigger line 29
    mock_wrapper = mock('wrapper')
    mock_wrapper.expects(:wrap).returns("calculator, weather,\nfile_reader")
    WordWrapper::MinimumRaggedness.expects(:new).with(80, 'calculator, weather_api, file_reader').returns(mock_wrapper)
    
    # Execute the method - this should hit ALL the missed lines:
    # Line 12: indent = 18
    # Line 13: spaces = " "*indent  
    # Line 14: width = TTY::Screen.width - indent - 2
    # Line 16: puts <<-ROBOT (heredoc start)
    # Line 24: tool_paths conditional (non-empty path)
    # Line 26: toolbox message (non-empty path) 
    # Line 28: if AIA.config.tools (non-nil tools)
    # Line 29: WordWrapper execution
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Verify the execution hit the key branches
    assert_includes output, "AI Assistant (v"
    assert_includes output, "gpt-4-turbo"
    assert_includes output, "using openai"
    assert_includes output, "2024-12-26"
    assert_includes output, "I will also use your tools"  # Line 24 branch
    assert_includes output, "My Toolbox contains:"        # Line 26 branch
    assert_includes output, "calculator, weather,"        # Line 29 execution
    assert_includes output, "file_reader"
    
  ensure
    # Restore original config method if it existed
    if original_config_method
      AIA.define_singleton_method(:config, &original_config_method)
    else
      # Restore the original stub from setup
      AIA.stubs(:config).returns(OpenStruct.new(
        model: 'claude-3-sonnet',
        adapter: 'anthropic',
        last_refresh: '2024-01-15',
        tool_paths: [],
        tools: 'calculator, weather_api, file_reader'
      ))
    end
  end
  
  def test_robot_executes_all_code_paths_without_tools
    # Test the other branch where tool_paths is empty
    AIA.unstub(:config)
    
    real_config = OpenStruct.new(
      model: 'claude-3',
      adapter: 'anthropic',
      last_refresh: '2024-12-26', 
      tool_paths: [],
      tools: nil
    )
    AIA.stubs(:config).returns(real_config)
    
    TTY::Screen.stubs(:width).returns(80)
    
    # This should hit lines 12, 13, 14, 16, 24, 26 but not 28, 29
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Verify the empty tool_paths branch
    assert_includes output, "AI Assistant"
    assert_includes output, "claude-3"
    assert_includes output, "anthropic"
    assert_includes output, "You can share my tools"
    refute_includes output, "My Toolbox contains:"
  end

  def test_robot_tool_text_formatting
    # Test that tools text is properly formatted and indented
    mock_wrapper = mock('wrapper')
    mock_wrapper.expects(:wrap).returns("tool1\ntool2")
    WordWrapper::MinimumRaggedness.expects(:new).returns(mock_wrapper)
    
    AIA.config.tools = 'tool1, tool2'
    AIA.config.tool_paths = ['/path']
    
    AIA::Utility.robot
    
    output = @captured_output.string
    
    # Each tool line should end with newline and be properly spaced
    assert_includes output, "tool1"
    assert_includes output, "tool2"
  end

  def test_robot_basic_execution_no_mocks
    # Minimal test to ensure basic variable assignments and method execution
    # This should hit lines 12, 13, 14, 16 without complex mocking
    
    minimal_config = OpenStruct.new(
      model: 'test-model',
      adapter: 'test-adapter',
      last_refresh: 'test-date',
      tool_paths: [],
      tools: nil
    )
    
    # Temporarily replace config and constants 
    original_config_method = AIA.method(:config) rescue nil
    AIA.define_singleton_method(:config) { minimal_config }
    
    # Mock constants to avoid dependency issues
    original_aia_version = AIA::VERSION rescue nil
    original_rubyllm_version = RubyLLM::VERSION rescue nil
    
    AIA.const_set(:VERSION, '1.0.0') unless AIA.const_defined?(:VERSION)
    RubyLLM.const_set(:VERSION, '1.0.0') unless RubyLLM.const_defined?(:VERSION)
    
    TTY::Screen.expects(:width).returns(80).at_least_once
    
    # This should execute the method and hit the variable assignment lines
    AIA::Utility.robot
    
    output = @captured_output.string
    assert_includes output, "AI Assistant (v0.9.9) is Online"
    
  ensure
    # Restore originals
    if original_config_method
      AIA.define_singleton_method(:config, &original_config_method)
    end
  end
end
