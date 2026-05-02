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
    mock_client.stubs(:name).returns('TestBot')
    AIA.stubs(:client).returns(mock_client)

    # Mock AIA.config with nested structure (matching new config layout)
    config = OpenStruct.new(
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'claude-3-sonnet')],
      tools: OpenStruct.new(paths: []),
      registry: OpenStruct.new(refresh: 7),
      paths: OpenStruct.new(aia_dir: '/tmp/aia_test'),
      tool_names: 'calculator, weather_api, file_reader',
      loaded_tools: [],
      mcp_servers: [],
      mcp_use: [],
      mcp_skip: [],
      connected_mcp_servers: nil,
      failed_mcp_servers: nil
    )
    AIA.stubs(:config).returns(config)

    # Mock models_last_refresh to return a known date
    AIA::Utility.stubs(:models_last_refresh).returns('2024-01-15 10:30')

    # Mock TTY::Screen.width
    TTY::Screen.stubs(:width).returns(100)
  end

  def teardown
    $stdout = @original_stdout
    super
  end

  def test_robot_displays_ascii_art
    AIA::Utility.robot

    output = @captured_output.string

    # Check for ASCII art elements (v2 robot)
    assert_includes output, "(\\____/)"
    assert_includes output, "(_oo_)"
    assert_includes output, "(O)"
    assert_includes output, "__|||__"
    assert_includes output, "[/ Tobor \\]"
    assert_includes output, "/ \\_______/ \\/"
    assert_includes output, "/___\\"
    assert_includes output, "/_____\\"
  end

  def test_robot_displays_version_information
    AIA::Utility.robot

    output = @captured_output.string

    assert_includes output, "AIA v#{AIA::VERSION} is Online"
    assert_includes output, "ruby_llm"
  end

  def test_robot_displays_model_information
    AIA::Utility.robot

    output = @captured_output.string

    assert_includes output, "claude-3-sonnet"
  end

  def test_robot_displays_last_refresh_date
    AIA::Utility.robot

    output = @captured_output.string

    # v2 format: "DB: refreshed YYYY-MM-DD at HH:MM"
    assert_includes output, "DB:"
    assert_includes output, "refreshed"
    assert_includes output, "2024-01-15"
    assert_includes output, "10:30"
  end

  def test_robot_with_no_tools
    AIA.config.tools.paths = []
    AIA.config.tool_names = ''
    AIA.config.loaded_tools = []

    AIA::Utility.robot

    output = @captured_output.string

    # v2 format: "Tools: none loaded"
    assert_includes output, "none loaded"
  end

  def test_robot_with_tools_available
    AIA.config.tool_names = 'calculator, weather_api, file_reader'
    AIA.config.loaded_tools = [mock('t1'), mock('t2'), mock('t3')]

    AIA::Utility.robot

    output = @captured_output.string

    # v2 format: "Tools: 3 tools loaded"
    assert_includes output, "3 tools loaded"
  end

  def test_robot_displays_tool_count
    AIA.config.tool_names = 'calculator, weather_api'
    AIA.config.loaded_tools = [mock('t1'), mock('t2')]

    AIA::Utility.robot

    output = @captured_output.string

    # v2 format: "Tools: 2 tools loaded"
    assert_includes output, "2 tools loaded"
  end

  def test_robot_handles_nil_tools
    AIA.config.tools = nil

    # Should not raise an error
    AIA::Utility.robot

    output = @captured_output.string
    assert_includes output, "AIA v"  # Should still display basic info
  end

  def test_robot_calculates_correct_width
    TTY::Screen.stubs(:width).returns(120)

    AIA::Utility.robot

    output = @captured_output.string
    assert_includes output, "AIA v"
  end

  def test_robot_banner_structure
    AIA::Utility.robot

    output = @captured_output.string

    # Verify key banner elements are present (v2 format)
    assert_includes output, "AIA v"
    assert_includes output, "is Online"
    assert_includes output, "ruby_llm"
    assert_includes output, "DB:"
    assert_includes output, "refreshed"
  end

  def test_robot_module_method_accessibility
    assert_respond_to AIA::Utility, :robot
  end

  def test_robot_with_edge_case_screen_widths
    # Test with very narrow screen
    TTY::Screen.stubs(:width).returns(25)

    # Should handle narrow width gracefully
    AIA::Utility.robot

    output = @captured_output.string
    # At very narrow widths the banner may be split across sections;
    # just verify it doesn't crash and produces some output
    refute_empty output
  end

  def test_robot_string_interpolation
    # Save original constants and config values
    original_aia_version     = AIA::VERSION
    original_rubyllm_version = RubyLLM::VERSION
    original_models          = AIA.config.models

    # Override for test
    AIA.const_set(:VERSION, 'X.Y.Z')
    RubyLLM.const_set(:VERSION, 'R.L.M')
    AIA.config.models = [OpenStruct.new(name: 'my-test-model')]

    AIA::Utility.robot
    output = @captured_output.string

    # v2 format: "AIA vX.Y.Z is Online"
    assert_includes output, "AIA vX.Y.Z is Online"
    assert_includes output, "ruby_llm vR.L.M"
    assert_includes output, 'my-test-model'

    # Restore originals
    AIA.const_set(:VERSION, original_aia_version)
    RubyLLM.const_set(:VERSION, original_rubyllm_version)
    AIA.config.models = original_models
  end

  def test_robot_with_empty_tools_string
    AIA.config.tool_names = ''
    AIA.config.tools = OpenStruct.new(paths: ['/path'])
    AIA.config.loaded_tools = []

    # Should not raise an error with empty tools string
    AIA::Utility.robot

    output = @captured_output.string
    assert_includes output, "AIA v"
  end

  def test_robot_executes_all_code_paths_with_tools
    AIA.unstub(:config)
    real_config = OpenStruct.new(
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'gpt-4-turbo')],
      registry: OpenStruct.new(refresh: 7),
      paths: OpenStruct.new(aia_dir: '/tmp/aia_test'),
      tools: OpenStruct.new(paths: ['/usr/local/tools', '/home/tools']),
      tool_names: 'calculator, weather_api, file_reader',
      loaded_tools: [],
      mcp_servers: [],
      mcp_use: [],
      mcp_skip: [],
      connected_mcp_servers: nil,
      failed_mcp_servers: nil
    )

    original_config_method = AIA.method(:config) rescue nil
    AIA.define_singleton_method(:config) { real_config }

    AIA::Utility.stubs(:models_last_refresh).returns('2024-12-26 14:30')
    TTY::Screen.expects(:width).returns(100).at_least_once

    AIA::Utility.robot

    output = @captured_output.string

    # Verify the execution hit the key branches (v2 format)
    assert_includes output, "AIA v"
    assert_includes output, "is Online"
    assert_includes output, "gpt-4-turbo"
    assert_includes output, "ruby_llm"
    assert_includes output, "2024-12-26"

  ensure
    if original_config_method
      AIA.define_singleton_method(:config, &original_config_method)
    else
      AIA.stubs(:config).returns(OpenStruct.new(
        llm: OpenStruct.new(temperature: 0.7),
        models: [OpenStruct.new(name: 'claude-3-sonnet')],
        registry: OpenStruct.new(last_refresh: '2024-01-15'),
        tools: OpenStruct.new(paths: []),
        tool_names: 'calculator, weather_api, file_reader',
        loaded_tools: [],
        mcp_servers: [],
        mcp_use: [],
        mcp_skip: [],
        connected_mcp_servers: nil,
        failed_mcp_servers: nil
      ))
    end
  end

  def test_robot_executes_all_code_paths_without_tools
    AIA.unstub(:config)

    real_config = OpenStruct.new(
      llm: OpenStruct.new(temperature: 0.7),
      models: [OpenStruct.new(name: 'claude-3')],
      registry: OpenStruct.new(last_refresh: '2024-12-26'),
      tools: OpenStruct.new(paths: []),
      tool_names: nil,
      loaded_tools: [],
      mcp_servers: [],
      mcp_use: [],
      mcp_skip: [],
      connected_mcp_servers: nil,
      failed_mcp_servers: nil
    )
    AIA.stubs(:config).returns(real_config)

    TTY::Screen.stubs(:width).returns(80)

    AIA::Utility.robot

    output = @captured_output.string

    # v2 format checks
    assert_includes output, "AIA v"
    assert_includes output, "claude-3"
    assert_includes output, "ruby_llm"
    assert_includes output, "none loaded"
  end

  def test_robot_tool_count_display
    AIA.config.tool_names = 'tool1, tool2'
    AIA.config.loaded_tools = [mock('t1'), mock('t2')]

    AIA::Utility.robot

    output = @captured_output.string

    # v2 format: "Tools: 2 tools loaded"
    assert_includes output, "2 tools loaded"
  end

end
