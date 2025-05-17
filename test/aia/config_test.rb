require_relative '../test_helper'
require 'ostruct'
require 'tempfile'
require_relative '../../lib/aia'

class ConfigTest < Minitest::Test
  def setup
    @default_config = AIA::Config::DEFAULT_CONFIG
  end

  def test_mcp_servers_default_empty
    config = AIA::Config.setup
    assert_equal [], config.mcp_servers
  end

  def test_mcp_server_config_file_not_found
    args = ['--mcp', 'nonexistent.json']
    
    stderr_output = capture_constant_stderr do
      assert_raises(SystemExit) do
        AIA::Config.cli_options.parse(args)
      end
    end
    
    assert_match(/MCP server config file not found/, stderr_output)
  end

  def test_mcp_server_invalid_json
    # Create a temporary file with invalid JSON
    temp_file = Tempfile.new(['mcp_config', '.json'])
    temp_file.write('invalid json')
    temp_file.close

    args = ['--mcp', temp_file.path]
    
    stderr_output = capture_constant_stderr do
      assert_raises(SystemExit) do
        AIA::Config.cli_options.parse(args)
      end
    end
    
    assert_match(/Error parsing MCP server config file/, stderr_output)
  ensure
    temp_file.unlink
  end

  def test_mcp_server_valid_config
    # Create a temporary file with valid JSON
    temp_file = Tempfile.new(['mcp_config', '.json'])
    server_config = { 'type' => 'stdio', 'command' => 'echo "test"' }
    temp_file.write(JSON.generate(server_config))
    temp_file.close

    args = ['--mcp', temp_file.path]
    config = AIA::Config.cli_options
    config.parse(args)
    
    assert_equal 1, config.mcp_servers.size
    assert_equal server_config, config.mcp_servers.first
  ensure
    temp_file.unlink
  end

  def test_multiple_mcp_servers
    # Create two temporary files with valid JSON
    temp_file1 = Tempfile.new(['mcp_config1', '.json'])
    temp_file2 = Tempfile.new(['mcp_config2', '.json'])
    
    server_config1 = { 'type' => 'stdio', 'command' => 'echo "test1"' }
    server_config2 = { 'type' => 'sse', 'url' => 'http://localhost:8080' }
    
    temp_file1.write(JSON.generate(server_config1))
    temp_file2.write(JSON.generate(server_config2))
    
    temp_file1.close
    temp_file2.close

    args = ['--mcp', temp_file1.path, '--mcp', temp_file2.path]
    config = AIA::Config.cli_options
    config.parse(args)
    
    assert_equal 2, config.mcp_servers.size
    assert_equal server_config1, config.mcp_servers[0]
    assert_equal server_config2, config.mcp_servers[1]
  ensure
    temp_file1.unlink
    temp_file2.unlink
  end

  def test_no_prompt_id_provided
    args = []

    # We need to capture output from STDERR constant, not just $stderr
    stderr_output = capture_constant_stderr do
      # This will call exit, but our test_helper has overridden exit
      # so it won't actually terminate the test
      AIA::Config.parse(args)
    end

    # Check that an error message about missing prompt ID was printed
    assert_match(/prompt id is required/i, stderr_output, "Expected error message about missing prompt ID")
  end

  def test_parse_command_line_arguments
    args = ['--model', 'custom-model', '--chat']
    config = AIA::Config.parse(args)
    assert_equal 'custom-model', config[:model], "Expected model to be 'custom-model'"
    assert_equal true, config[:chat], "Expected chat to be true"
    assert config.prompt_id.nil? || config.prompt_id.empty?, "Expected prompt_id to be nil or empty"
  end

  def test_parse_environment_variables
    ENV['AIA_MODEL'] = 'env-model'
    config = AIA::Config.parse([])
    assert_equal 'env-model', config.model
  ensure
    ENV.delete('AIA_MODEL')
  end

  # Helper method to capture output from the STDERR constant
  def capture_constant_stderr
    old_stderr = STDERR.dup
    io = Tempfile.new("stderr")
    STDERR.reopen(io.path, "w")

    yield

    STDERR.reopen(old_stderr)
    io.rewind
    output = io.read
    io.close
    io.unlink

    output
  end
end
