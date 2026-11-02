# frozen_string_literal: true

# test/aia/mcp_server_classes_test.rb
#
# mcp_servers: entries that name a RubyLLM::MCP subclass ("SharedTools::MCP::Memory")
# instead of describing a server with a Hash. The class is loaded by --require;
# a class that reports itself unavailable (missing API key) is skipped.

require_relative '../test_helper'
require_relative '../../lib/aia'

class MCPServerClassesTest < Minitest::Test
  # A server class described entirely by ruby_llm's class DSL.
  class EchoServer < RubyLLM::MCP
    command 'echo', 'hello'
    timeout 45
  end

  # A remote server class.
  class RemoteServer < RubyLLM::MCP
    url 'https://example.test/mcp'
  end

  # A server class that, like shared_tools' clients, can report that its
  # API key is missing.
  class KeyedServer < RubyLLM::MCP
    command 'keyed-server'

    class << self
      attr_accessor :key_present

      def available? = key_present == true
      def missing_envars = key_present ? [] : %w[KEYED_TOKEN]
    end
  end

  ECHO = 'MCPServerClassesTest::EchoServer'

  def setup
    KeyedServer.key_present = true
  end

  # --- AIA::Utility.server_name / mcp_class_name? ---

  def test_server_name_of_a_class_is_its_default_name
    assert_equal 'echo_server', AIA::Utility.server_name(EchoServer)
  end

  def test_server_name_of_a_constant_name_resolves_the_class
    assert_equal 'echo_server', AIA::Utility.server_name(ECHO)
  end

  def test_server_name_of_an_undefined_constant_is_the_constant_name
    assert_equal 'Not::Loaded::Server', AIA::Utility.server_name('Not::Loaded::Server')
  end

  def test_server_name_of_hash_and_plain_string_unchanged
    assert_equal 'fs', AIA::Utility.server_name({ name: 'fs' })
    assert_equal 'filesystem', AIA::Utility.server_name('filesystem')
  end

  def test_mcp_class_name_matches_constant_paths_only
    assert AIA::Utility.mcp_class_name?('SharedTools::MCP::GitHub')
    assert AIA::Utility.mcp_class_name?('GitHub')
    refute AIA::Utility.mcp_class_name?('github')
    refute AIA::Utility.mcp_class_name?('Shared Tools')
    refute AIA::Utility.mcp_class_name?({ name: 'X' })
  end

  # --- AIA::MCPDiscovery#resolve_entries ---

  def test_resolve_entries_turns_constant_names_into_classes
    hash = { name: 'fs', command: 'npx' }
    assert_equal [EchoServer, hash, EchoServer], AIA::MCPDiscovery.new.resolve_entries([ECHO, hash, EchoServer])
  end

  def test_resolve_entries_skips_an_unavailable_class_with_its_missing_envars
    KeyedServer.key_present = false
    _out, err = capture_io do
      assert_equal [], AIA::MCPDiscovery.new.resolve_entries(['MCPServerClassesTest::KeyedServer'])
    end
    assert_includes err, "MCP server 'keyed_server' skipped (missing KEYED_TOKEN)"
  end

  def test_resolve_entries_keeps_an_available_class
    assert_equal [KeyedServer], AIA::MCPDiscovery.new.resolve_entries([KeyedServer])
  end

  def test_resolve_entries_skips_an_undefined_constant
    _out, err = capture_io do
      assert_equal [], AIA::MCPDiscovery.new.resolve_entries(['Not::Loaded::Server'])
    end
    assert_match(/MCP server 'Not::Loaded::Server' skipped \(.*not defined/, err)
  end

  def test_discover_resolves_after_use_and_skip_selection
    config = OpenStruct.new(flags: OpenStruct.new(no_mcp: false), mcp_servers: [ECHO, { name: 'fs' }],
                            mcp_use: [], mcp_skip: ['fs'])
    assert_equal [EchoServer], AIA::MCPDiscovery.new.discover(config)
  end

  # --- AIA::MCPConfigNormalizer.normalize ---

  def test_normalize_passes_classes_instances_and_constant_names_through
    instance = EchoServer.new
    assert_same EchoServer, AIA::MCPConfigNormalizer.normalize(EchoServer)
    assert_same instance,   AIA::MCPConfigNormalizer.normalize(instance)
    assert_equal ECHO,      AIA::MCPConfigNormalizer.normalize(ECHO)
  end

  def test_normalized_class_builds_through_robot_lab
    assert_instance_of EchoServer, RobotLab::MCP.build(AIA::MCPConfigNormalizer.normalize(ECHO))
  end

  # --- AIA::MCPGrouper ---

  def test_grouper_treats_a_class_as_an_independent_server
    groups = AIA::MCPGrouper.new.group([EchoServer, ECHO, { name: 'a', group: 'g' }, { name: 'b', group: 'g' }])
    assert_includes groups, [EchoServer]
    assert_includes groups, [ECHO]
    assert_includes groups, [{ name: 'a', group: 'g' }, { name: 'b', group: 'g' }]
  end

  # --- AIA::McpServerConfig ---

  def test_server_config_from_a_stdio_class
    cfg = AIA::McpServerConfig.from_hash(EchoServer)
    assert_equal 'echo_server', cfg.name
    assert_equal 'echo', cfg.command
    assert_equal ['hello'], cfg.args
    assert_equal 45, cfg.timeout_raw
    assert_nil cfg.url
  end

  def test_server_config_from_a_remote_class_has_its_url
    cfg = AIA::McpServerConfig.from_hash(RemoteServer)
    assert_nil cfg.command
    assert_equal 'https://example.test/mcp', cfg.url
  end

  def test_server_config_from_an_unloaded_constant_name_has_only_a_name
    cfg = AIA::McpServerConfig.from_hash('Not::Loaded::Server')
    assert_equal 'Not::Loaded::Server', cfg.name
    assert_nil cfg.command
    assert_equal [], cfg.args
  end

  def test_server_config_from_hash_reads_url
    cfg = AIA::McpServerConfig.from_hash({ name: 'remote', url: 'https://x.test/mcp' })
    assert_equal 'https://x.test/mcp', cfg.url
  end

  # --- AIA::MCPConnectionManager#server_timeout ---

  def test_server_timeout_uses_a_class_timeout
    manager = AIA::MCPConnectionManager.new
    assert_in_delta 45.0, manager.send(:server_timeout, EchoServer)
  end

  def test_server_timeout_defaults_for_a_class_without_one
    manager = AIA::MCPConnectionManager.new
    assert_equal AIA::MCPConnectionManager::DEFAULT_TIMEOUT, manager.send(:server_timeout, RemoteServer)
  end
end
