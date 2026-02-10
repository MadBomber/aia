# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'
require 'fileutils'

class ToolLoaderTest < Minitest::Test
  def setup
    @mock_mcp = mock('mcp_connector')
    @loader = AIA::Adapter::ToolLoader.new(@mock_mcp)
  end

  def teardown
    super
  end

  def test_class_exists
    assert_kind_of Class, AIA::Adapter::ToolLoader
  end

  def test_initializes_with_mcp_connector
    assert_kind_of AIA::Adapter::ToolLoader, @loader
  end

  # --- scan_local_tools ---

  def test_scan_local_tools_returns_array
    AIA.stubs(:config).returns(OpenStruct.new(
      require_libs: nil,
      tools: OpenStruct.new(paths: nil)
    ))

    result = @loader.scan_local_tools
    assert_kind_of Array, result
  end

  def test_scan_local_tools_with_nil_require_libs
    AIA.stubs(:config).returns(OpenStruct.new(
      require_libs: nil,
      tools: OpenStruct.new(paths: nil)
    ))

    # Should not raise
    @loader.scan_local_tools
  end

  def test_scan_local_tools_with_empty_require_libs
    AIA.stubs(:config).returns(OpenStruct.new(
      require_libs: [],
      tools: OpenStruct.new(paths: [])
    ))

    # Should not raise
    result = @loader.scan_local_tools
    assert_kind_of Array, result
  end

  # --- load_tool_files ---

  def test_load_tool_files_with_nil_paths
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(paths: nil)
    ))

    # Should not raise
    @loader.send(:load_tool_files)
  end

  def test_load_tool_files_with_empty_paths
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(paths: [])
    ))

    # Should not raise
    @loader.send(:load_tool_files)
  end

  def test_load_tool_files_warns_on_missing_file
    AIA.stubs(:config).returns(OpenStruct.new(
      tools: OpenStruct.new(paths: ['/nonexistent/tool_file.rb'])
    ))

    @loader.expects(:warn).with(regexp_matches(/Tool file not found/))

    @loader.send(:load_tool_files)
  end

  def test_load_tool_files_loads_existing_file
    Dir.mktmpdir do |tmpdir|
      tool_file = File.join(tmpdir, 'my_tool.rb')
      File.write(tool_file, '# empty tool file')

      AIA.stubs(:config).returns(OpenStruct.new(
        tools: OpenStruct.new(paths: [tool_file])
      ))

      # Should not raise
      @loader.send(:load_tool_files)
    end
  end

  def test_load_tool_files_warns_on_load_error
    Dir.mktmpdir do |tmpdir|
      tool_file = File.join(tmpdir, 'bad_tool.rb')
      File.write(tool_file, 'raise LoadError, "intentional error"')

      AIA.stubs(:config).returns(OpenStruct.new(
        tools: OpenStruct.new(paths: [tool_file])
      ))

      @loader.expects(:warn).with(regexp_matches(/Failed to load tool file/))

      @loader.send(:load_tool_files)
    end
  end

  # --- load_require_libs ---

  def test_load_require_libs_with_nil_config
    AIA.stubs(:config).returns(OpenStruct.new(
      require_libs: nil
    ))

    # Should not raise
    @loader.send(:load_require_libs)
  end

  def test_load_require_libs_warns_on_missing_gem
    AIA.stubs(:config).returns(OpenStruct.new(
      require_libs: ['totally_nonexistent_gem_xyz_123']
    ))

    AIA::Adapter::GemActivator.stubs(:activate_gem_for_require)
    AIA::Adapter::GemActivator.stubs(:trigger_tool_loading)

    warn_messages = []
    @loader.stubs(:warn).with { |msg| warn_messages << msg; true }

    @loader.send(:load_require_libs)

    assert warn_messages.any? { |m| m =~ /Failed to require library/ },
           "Expected a warn call matching /Failed to require library/, got: #{warn_messages.inspect}"
  end

  # --- load_tools_with_mcp ---

  def test_load_tools_with_mcp_calls_mcp_connector
    AIA.stubs(:config).returns(OpenStruct.new(
      require_libs: nil,
      tools: OpenStruct.new(paths: nil)
    ))

    @mock_mcp.expects(:support_mcp_with_simple_flow).with(kind_of(Array))

    @loader.load_tools_with_mcp
  end

  # --- load_tools_legacy ---

  def test_load_tools_legacy_calls_support_mcp
    AIA.stubs(:config).returns(OpenStruct.new(
      require_libs: nil,
      tools: OpenStruct.new(paths: nil)
    ))

    @mock_mcp.expects(:support_mcp).with(kind_of(Array))

    @loader.load_tools_legacy
  end
end
