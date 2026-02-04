require_relative '../../test_helper'
require 'json'
require 'tempfile'

class McpParserTest < Minitest::Test
  def test_parse_files_with_nil
    assert_equal [], AIA::McpParser.parse_files(nil)
  end

  def test_parse_files_with_empty_array
    assert_equal [], AIA::McpParser.parse_files([])
  end

  def test_parse_files_with_nonexistent_file
    result = AIA::McpParser.parse_files(['/nonexistent/path/config.json'])
    assert_equal [], result
  end

  def test_parse_mcp_servers_format
    json = {
      "mcpServers" => {
        "filesystem" => {
          "command" => "npx",
          "args" => ["-y", "@modelcontextprotocol/server-filesystem"],
          "env" => { "HOME" => "/tmp" },
          "timeout" => 5000
        },
        "database" => {
          "command" => "python",
          "args" => ["-m", "db_server"],
          "url" => "http://localhost:3000",
          "headers" => { "Authorization" => "Bearer token" }
        }
      }
    }

    with_temp_json(json) do |path|
      servers = AIA::McpParser.parse_files([path])
      assert_equal 2, servers.size

      fs = servers.find { |s| s[:name] == "filesystem" }
      assert_equal "npx", fs[:command]
      assert_equal ["-y", "@modelcontextprotocol/server-filesystem"], fs[:args]
      assert_equal({ "HOME" => "/tmp" }, fs[:env])
      assert_equal 5000, fs[:timeout]

      db = servers.find { |s| s[:name] == "database" }
      assert_equal "python", db[:command]
      assert_equal ["-m", "db_server"], db[:args]
      assert_equal "http://localhost:3000", db[:url]
      assert_equal({ "Authorization" => "Bearer token" }, db[:headers])
    end
  end

  def test_parse_simple_format_with_array_command
    json = {
      "type" => "stdio",
      "command" => ["npx", "-y", "@server/name", "/path"]
    }

    Tempfile.create(['test_mcp', '.json']) do |f|
      f.write(JSON.generate(json))
      f.flush

      servers = AIA::McpParser.parse_files([f.path])
      assert_equal 1, servers.size

      server = servers.first
      # Name derived from temp file basename
      assert_kind_of String, server[:name]
      assert_equal "npx", server[:command]
      assert_equal ["-y", "@server/name", "/path"], server[:args]
      assert_equal "stdio", server[:type]
    end
  end

  def test_parse_simple_format_with_string_command
    json = {
      "command" => "python",
      "args" => ["-m", "module_name"],
      "env" => { "KEY" => "value" },
      "timeout" => 3000
    }

    with_temp_json(json) do |path|
      servers = AIA::McpParser.parse_files([path])
      assert_equal 1, servers.size

      server = servers.first
      assert_equal "python", server[:command]
      assert_equal ["-m", "module_name"], server[:args]
      assert_equal({ "KEY" => "value" }, server[:env])
      assert_equal 3000, server[:timeout]
    end
  end

  def test_parse_multiple_files
    json1 = { "mcpServers" => { "s1" => { "command" => "cmd1" } } }
    json2 = { "mcpServers" => { "s2" => { "command" => "cmd2" } } }

    with_temp_json(json1) do |path1|
      with_temp_json(json2) do |path2|
        servers = AIA::McpParser.parse_files([path1, path2])
        assert_equal 2, servers.size
        names = servers.map { |s| s[:name] }
        assert_includes names, "s1"
        assert_includes names, "s2"
      end
    end
  end

  def test_parse_invalid_json
    Tempfile.create(['test_mcp', '.json']) do |f|
      f.write("not valid json {{{")
      f.flush

      result = AIA::McpParser.parse_files([f.path])
      assert_equal [], result
    end
  end

  def test_parse_mcp_servers_minimal
    json = {
      "mcpServers" => {
        "minimal" => {
          "command" => "node"
        }
      }
    }

    with_temp_json(json) do |path|
      servers = AIA::McpParser.parse_files([path])
      assert_equal 1, servers.size
      assert_equal "minimal", servers.first[:name]
      assert_equal "node", servers.first[:command]
      assert_nil servers.first[:args]
      assert_nil servers.first[:env]
      assert_nil servers.first[:timeout]
    end
  end

  def test_server_name_derived_from_filename
    Dir.mktmpdir do |dir|
      path = File.join(dir, "my_server.json")
      File.write(path, JSON.generate({ "command" => "ruby" }))

      servers = AIA::McpParser.parse_files([path])
      assert_equal "my_server", servers.first[:name]
    end
  end

  def test_parse_mixed_nonexistent_and_valid
    json = { "mcpServers" => { "valid" => { "command" => "test" } } }

    with_temp_json(json) do |path|
      servers = AIA::McpParser.parse_files(["/nonexistent.json", path])
      assert_equal 1, servers.size
      assert_equal "valid", servers.first[:name]
    end
  end

  private

  def with_temp_json(data, &block)
    Tempfile.create(['test_mcp', '.json']) do |f|
      f.write(JSON.generate(data))
      f.flush
      block.call(f.path)
    end
  end
end
