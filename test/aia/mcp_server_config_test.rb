# frozen_string_literal: true

# test/aia/mcp_server_config_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class McpServerConfigTest < Minitest::Test
  # =========================================================================
  # from_hash — key fallback unpacking
  # =========================================================================

  def test_from_hash_with_symbol_keys_and_nested_transport
    server = {
      name: 'files',
      transport: { command: 'npx', args: ['-y', 'server'], env: { 'K' => 'v' } },
      timeout: 5000
    }
    config = AIA::McpServerConfig.from_hash(server)

    assert_equal 'files', config.name
    assert_equal 'npx', config.command
    assert_equal ['-y', 'server'], config.args
    assert_equal({ 'K' => 'v' }, config.env)
    assert_equal 5000, config.timeout_raw
  end

  def test_from_hash_with_string_keys_and_nested_transport
    server = {
      'name'      => 'files',
      'transport' => { 'command' => 'npx', 'args' => ['a'], 'env' => { 'K' => 'v' } },
      'timeout'   => 7
    }
    config = AIA::McpServerConfig.from_hash(server)

    assert_equal 'files', config.name
    assert_equal 'npx', config.command
    assert_equal ['a'], config.args
    assert_equal({ 'K' => 'v' }, config.env)
    assert_equal 7, config.timeout_raw
  end

  def test_from_hash_falls_back_to_top_level_fields
    server = { name: 'flat', command: 'ruby', args: ['tool.rb'], env: { 'X' => '1' } }
    config = AIA::McpServerConfig.from_hash(server)

    assert_equal 'ruby', config.command
    assert_equal ['tool.rb'], config.args
    assert_equal({ 'X' => '1' }, config.env)
  end

  def test_from_hash_transport_fields_win_over_top_level
    server = {
      name: 'both',
      command: 'outer',
      transport: { command: 'inner' }
    }
    assert_equal 'inner', AIA::McpServerConfig.from_hash(server).command
  end

  def test_from_hash_defaults_for_missing_fields
    config = AIA::McpServerConfig.from_hash({ name: 'bare' })

    assert_nil config.command
    assert_equal [], config.args
    assert_equal({}, config.env)
    assert_nil config.timeout_raw
  end

  def test_from_hash_unnamed_server_has_nil_name
    assert_nil AIA::McpServerConfig.from_hash({ command: 'x' }).name
  end

  # =========================================================================
  # timeout_ms — normalization
  # =========================================================================

  def test_timeout_ms_defaults_to_8000
    config = AIA::McpServerConfig.from_hash({ name: 'n' })
    assert_equal 8_000, config.timeout_ms
  end

  def test_timeout_ms_treats_small_values_as_seconds
    config = AIA::McpServerConfig.from_hash({ name: 'n', timeout: 5 })
    assert_equal 5_000, config.timeout_ms
  end

  def test_timeout_ms_keeps_millisecond_values
    config = AIA::McpServerConfig.from_hash({ name: 'n', timeout: 12_000 })
    assert_equal 12_000, config.timeout_ms
  end

  def test_timeout_ms_caps_at_30000
    config = AIA::McpServerConfig.from_hash({ name: 'n', timeout: 90_000 })
    assert_equal 30_000, config.timeout_ms
  end

  def test_timeout_ms_honors_custom_default_and_cap
    config = AIA::McpServerConfig.from_hash({ name: 'n' })
    assert_equal 2_000, config.timeout_ms(default: 2_000)

    config = AIA::McpServerConfig.from_hash({ name: 'n', timeout: 90_000 })
    assert_equal 60_000, config.timeout_ms(cap: 60_000)
  end
end
