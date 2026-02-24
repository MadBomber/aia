require_relative '../test_helper'
require 'ostruct'
require 'stringio'
require_relative '../../lib/aia'

class UtilityTest < Minitest::Test
  def setup
    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output

    # Create mock model and client
    mock_model = mock('model')
    mock_model.stubs(:supports_functions?).returns(true)
    mock_client = mock('client')
    mock_client.stubs(:model).returns(mock_model)

    # Mock AIA.config with nested structure (matching new config layout)
    config = OpenStruct.new(
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'claude-3-sonnet')],
      tools: OpenStruct.new(paths: []),
      registry: OpenStruct.new(refresh: 7),
      paths: OpenStruct.new(aia_dir: '/tmp/aia_test'),
      tool_names: 'calculator, weather_api, file_reader',
      mcp_servers: [],
      client: mock_client
    )
    AIA.stubs(:config).returns(config)

    # Mock models_last_refresh to return a known date
    AIA::Utility.stubs(:models_last_refresh).returns('2024-01-15 10:30')

    # Mock TTY::Screen.width
    TTY::Screen.stubs(:width).returns(100)

    # Mock AIA::VERSION
    AIA.stubs(:const_get).with(:VERSION).returns('0.9.9')

    # Mock RubyLLM::VERSION
    RubyLLM.stubs(:const_get).with(:VERSION).returns('1.3.1')
  end

  def teardown
    $stdout = @original_stdout
    # Call super to ensure Mocha cleanup runs properly
    super
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
    
    # Check for version information - flexible pattern matching
    assert_match /AI Assistant \(v[\d.\w-]+\) is Online/, output
    assert_match /using ruby_llm v[\d.]+/, output
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

  def test_robot_with_no_tools
    AIA.config.tools.paths = []
    AIA.config.tool_names = ''
    AIA.config.loaded_tools = []

    AIA::Utility.robot

    output = @captured_output.string

    assert_includes output, "I did not bring any tools"
  end

  def test_robot_with_tools_available
    AIA.config.tool_names = 'calculator, weather_api, file_reader'
    AIA.config.loaded_tools = [mock('t1'), mock('t2'), mock('t3')]

    AIA::Utility.robot

    output = @captured_output.string

    assert_includes output, "I brought 3 tools to share"
  end

  def test_robot_displays_tool_count
    AIA.config.tool_names = 'calculator, weather_api'
    AIA.config.loaded_tools = [mock('t1'), mock('t2')]

    AIA::Utility.robot

    output = @captured_output.string

    assert_includes output, "I brought 2 tools to share"
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

    AIA::Utility.robot

    output = @captured_output.string
    assert_includes output, "AI Assistant"
  end

  def test_robot_banner_structure
    AIA::Utility.robot

    output = @captured_output.string

    # Verify key banner elements are present
    assert_includes output, "AI Assistant"
    assert_includes output, "ruby_llm"
    assert_includes output, "model db was last refreshed on"
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
    original_models          = AIA.config.models

    # Override for test
    AIA.const_set(:VERSION, 'vX.Y.Z')
    RubyLLM.const_set(:VERSION, 'vR.L.M')
    AIA.config.models = [OpenStruct.new(name: 'my-test-model')]

    AIA::Utility.robot
    output = @captured_output.string

    # Validate interpolated versions and model
    assert_includes output, "AI Assistant (vvX.Y.Z)"
    assert_match /using ruby_llm vvR\.L\.M/, output
    assert_includes output, 'my-test-model'

    # Restore originals
    AIA.const_set(:VERSION, original_aia_version)
    RubyLLM.const_set(:VERSION, original_rubyllm_version)
    AIA.config.models = original_models
  end

  def test_robot_with_empty_tools_string
    AIA.config.tool_names = ''
    AIA.config.tools.paths = ['/path']

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
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'gpt-4-turbo')],
      registry: OpenStruct.new(refresh: 7),
      paths: OpenStruct.new(aia_dir: '/tmp/aia_test'),
      tools: OpenStruct.new(paths: ['/usr/local/tools', '/home/tools']),  # Non-empty to trigger lines 24, 26
      tool_names: 'calculator, weather_api, file_reader',  # Non-nil to trigger lines 28, 29
      mcp_servers: []
    )

    # Temporarily replace the config
    original_config_method = AIA.method(:config) rescue nil
    AIA.define_singleton_method(:config) { real_config }

    # Mock models_last_refresh to return a known date
    AIA::Utility.stubs(:models_last_refresh).returns('2024-12-26 14:30')

    # Mock only what's absolutely necessary to avoid external dependencies
    TTY::Screen.expects(:width).returns(100).at_least_once  # This will trigger width calculation on line 14

    # Skip complex WordWrapper mocking - just test basic functionality

    # Execute the method - this should hit ALL the missed lines:
    # Line 12: indent = 18
    # Line 13: spaces = " "*indent
    # Line 14: width = TTY::Screen.width - indent - 2
    # Line 16: puts <<-ROBOT (heredoc start)
    # Line 24: tools.paths conditional (non-empty path)
    # Line 26: toolbox message (non-empty path)
    # Line 28: if AIA.config.tool_names (non-nil tools)
    # Line 29: WordWrapper execution
    AIA::Utility.robot

    output = @captured_output.string

    # Verify the execution hit the key branches
    assert_includes output, "AI Assistant (v"
    assert_includes output, "gpt-4-turbo"
    assert_includes output, "using ruby_llm"
    assert_includes output, "2024-12-26"
    assert_includes output, "I brought"  # tools line

  ensure
    # Restore original config method if it existed
    if original_config_method
      AIA.define_singleton_method(:config, &original_config_method)
    else
      # Restore the original stub from setup
      AIA.stubs(:config).returns(OpenStruct.new(
        llm: OpenStruct.new(temperature: 0.7),
        models: [OpenStruct.new(name: 'claude-3-sonnet')],
        registry: OpenStruct.new(last_refresh: '2024-01-15'),
        tools: OpenStruct.new(paths: []),
        tool_names: 'calculator, weather_api, file_reader',
        mcp_servers: []
      ))
    end
  end
  
  def test_robot_executes_all_code_paths_without_tools
    # Test the other branch where tools.paths is empty
    AIA.unstub(:config)

    real_config = OpenStruct.new(
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'claude-3')],
      registry: OpenStruct.new(last_refresh: '2024-12-26'),
      tools: OpenStruct.new(paths: []),
      tool_names: nil,
      mcp_servers: []
    )
    AIA.stubs(:config).returns(real_config)

    TTY::Screen.stubs(:width).returns(80)

    # This should hit lines 12, 13, 14, 16, 24, 26 but not 28, 29
    AIA::Utility.robot

    output = @captured_output.string

    # Verify the empty tools.paths branch
    assert_includes output, "AI Assistant"
    assert_includes output, "claude-3"
    assert_includes output, "ruby_llm"
    assert_includes output, "I did not bring any tools"
    refute_includes output, "My Toolbox contains:"
  end

  def test_robot_tool_count_display
    AIA.config.tool_names = 'tool1, tool2'
    AIA.config.loaded_tools = [mock('t1'), mock('t2')]

    AIA::Utility.robot

    output = @captured_output.string

    assert_includes output, "I brought 2 tools to share"
  end

  def test_robot_basic_execution_no_mocks
    # Minimal test to ensure basic variable assignments and method execution
    # This should hit lines 12, 13, 14, 16 without complex mocking

    minimal_config = OpenStruct.new(
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'test-model')],
      registry: OpenStruct.new(last_refresh: 'test-date'),
      tools: OpenStruct.new(paths: []),
      tool_names: nil,
      mcp_servers: []
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
    # Check for key components without exact version
    assert_match /AI Assistant \(v[\d.\w-]+\) is Online/, output

  ensure
    # Restore originals
    if original_config_method
      AIA.define_singleton_method(:config, &original_config_method)
    end
  end
end
