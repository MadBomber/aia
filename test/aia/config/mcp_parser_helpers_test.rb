# frozen_string_literal: true

# test/aia/config/mcp_parser_helpers_test.rb
#
# Isolation tests for the transport and server builders extracted from
# McpParser::convert_mcp_servers_format.

require_relative '../../test_helper'

class McpParserHelpersTest < Minitest::Test
  # =========================================================================
  # build_transport
  # =========================================================================

  def test_build_transport_defaults_to_stdio
    assert_equal({ type: 'stdio' }, AIA::McpParser.send(:build_transport, {}))
  end

  def test_build_transport_maps_all_optional_keys
    config = {
      'type'    => 'sse',
      'command' => 'npx',
      'args'    => 'single',
      'env'     => { 'K' => 'v' },
      'url'     => 'http://x',
      'headers' => { 'H' => '1' }
    }
    transport = AIA::McpParser.send(:build_transport, config)

    assert_equal 'sse', transport[:type]
    assert_equal 'npx', transport[:command]
    assert_equal ['single'], transport[:args]
    assert_equal({ 'K' => 'v' }, transport[:env])
    assert_equal 'http://x', transport[:url]
    assert_equal({ 'H' => '1' }, transport[:headers])
  end

  # =========================================================================
  # build_server
  # =========================================================================

  def test_build_server_omits_group_when_absent
    server = AIA::McpParser.send(:build_server, 's', { 'command' => 'x' })
    refute server.key?(:group)
  end

  def test_build_server_keeps_group_and_drops_topics
    server = AIA::McpParser.send(:build_server, 's',
                                 { 'command' => 'x', 'topics' => 'files', 'group' => 'g1' })
    assert_equal 'g1', server[:group]
    refute server.key?(:topics)
  end

  # =========================================================================
  # json_type
  # =========================================================================

  def test_json_type_names_each_json_value_type
    {
      {} => 'an object', [] => 'an array', 'x' => 'a string',
      1 => 'a number', 1.5 => 'a number', true => 'a boolean', false => 'a boolean', nil => 'null'
    }.each do |value, expected|
      assert_equal expected, AIA::McpParser.send(:json_type, value)
    end
  end
end
