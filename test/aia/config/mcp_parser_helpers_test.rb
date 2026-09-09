# frozen_string_literal: true

# test/aia/config/mcp_parser_helpers_test.rb
#
# Isolation tests for the transport/metadata builders extracted from
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
  # routing_metadata
  # =========================================================================

  def test_routing_metadata_empty_when_absent
    assert_equal({}, AIA::McpParser.send(:routing_metadata, {}))
  end

  def test_routing_metadata_preserves_false_independent
    meta = AIA::McpParser.send(:routing_metadata,
                               'topics' => 'files', 'independent' => false, 'group' => 'g1')
    assert_equal ['files'], meta[:topics]
    assert_equal false, meta[:independent]
    assert_equal 'g1', meta[:group]
  end
end
