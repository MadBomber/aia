require_relative 'test_helper'
require 'open3'
require_relative '../lib/aia'

class CLITest < Minitest::Test
  BIN = File.expand_path('../bin/aia', __dir__)

  def test_help_option
    stdout, stderr, status = Open3.capture3('ruby', BIN, '--help')
    assert status.success?, "Expected exit status 0, got \\#{status.exitstatus}"
    assert_includes stdout, 'Usage:'
  end

  def test_version_option
    stdout, stderr, status = Open3.capture3('ruby', BIN, '--version')
    assert status.success?
    expected = AIA::VERSION + "\n"
    assert_equal expected, stdout
  end

  def test_mcp_list_exits_successfully
    stdout, stderr, status = Open3.capture3('ruby', BIN, '--mcp-list')
    assert status.success?, "Expected exit status 0, got #{status.exitstatus}"
    # Output will be either "No MCP servers configured." or "Configured MCP servers:"
    # depending on user's config file
    assert(stdout.include?('No MCP servers configured.') || stdout.include?('Configured MCP servers'),
           "Expected MCP list output, got: #{stdout}")
  end

  def test_mcp_list_with_mcp_file
    # Find a valid MCP JSON file in the mcp_servers directory
    mcp_dir = File.expand_path('../mcp_servers', __dir__)
    json_files = Dir.glob(File.join(mcp_dir, '*.json'))
    skip "No MCP JSON files found in mcp_servers/" if json_files.empty?

    mcp_file = json_files.first
    stdout, stderr, status = Open3.capture3('ruby', BIN, '--mcp', mcp_file, '--mcp-list')
    assert status.success?, "Expected exit status 0, got #{status.exitstatus}. stderr: #{stderr}"
    assert_includes stdout, 'Configured MCP servers'
  end
end