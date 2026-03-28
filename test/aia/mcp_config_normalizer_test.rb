# frozen_string_literal: true
# test/aia/mcp_config_normalizer_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/mcp_config_normalizer'

class MCPConfigNormalizerTest < Minitest::Test
  def test_normalize_pass_through_when_transport_present
    server = { name: 'test', transport: { type: 'stdio', command: 'cmd' } }
    result = AIA::MCPConfigNormalizer.normalize(server)
    assert_equal server, result
  end

  def test_normalize_wraps_flat_format_into_transport
    server = { name: 'test', command: 'my-cmd', args: ['--flag'] }
    result = AIA::MCPConfigNormalizer.normalize(server)
    assert_equal 'test', result[:name]
    assert_equal 'my-cmd', result[:transport][:command]
    assert_equal ['--flag'], result[:transport][:args]
  end

  def test_normalize_converts_string_keys
    server = { 'name' => 'test', 'command' => 'cmd' }
    result = AIA::MCPConfigNormalizer.normalize(server)
    assert_equal 'test', result[:name]
    assert_equal 'cmd', result[:transport][:command]
  end

end
