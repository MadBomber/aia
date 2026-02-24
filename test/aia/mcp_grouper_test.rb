# frozen_string_literal: true
# test/aia/mcp_grouper_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class MCPGrouperTest < Minitest::Test
  def setup
    @grouper = AIA::MCPGrouper.new
  end

  def teardown
    super
  end

  def test_group_with_empty_array_returns_empty
    result = @grouper.group([])

    assert_equal [], result
  end

  def test_group_with_nil_returns_empty
    result = @grouper.group(nil)

    assert_equal [], result
  end

  def test_group_puts_ungrouped_servers_in_individual_groups
    servers = [
      { name: 'server_a' },
      { name: 'server_b' },
      { name: 'server_c' }
    ]

    result = @grouper.group(servers)

    assert_equal 3, result.length
    result.each do |group|
      assert_equal 1, group.length, "Each ungrouped server should be in its own group"
    end
    names = result.map { |g| g.first[:name] }
    assert_includes names, 'server_a'
    assert_includes names, 'server_b'
    assert_includes names, 'server_c'
  end

  def test_group_puts_servers_with_same_group_together
    servers = [
      { name: 'server_a', group: 'code' },
      { name: 'server_b', group: 'code' },
      { name: 'server_c', group: 'code' }
    ]

    result = @grouper.group(servers)

    assert_equal 1, result.length
    assert_equal 3, result.first.length
    names = result.first.map { |s| s[:name] }
    assert_includes names, 'server_a'
    assert_includes names, 'server_b'
    assert_includes names, 'server_c'
  end

  def test_group_handles_mix_of_grouped_and_ungrouped
    servers = [
      { name: 'standalone_1' },
      { name: 'code_a', group: 'code' },
      { name: 'standalone_2' },
      { name: 'code_b', group: 'code' },
      { name: 'data_a', group: 'data' }
    ]

    result = @grouper.group(servers)

    # 2 independent (standalone) + 1 code group + 1 data group = 4 groups
    assert_equal 4, result.length

    # First two groups are the independent servers
    standalone_names = result[0..1].map { |g| g.first[:name] }
    assert_includes standalone_names, 'standalone_1'
    assert_includes standalone_names, 'standalone_2'

    # Find the code group (has 2 servers)
    code_group = result.find { |g| g.length == 2 }
    refute_nil code_group, "Should find a group with 2 servers"
    code_names = code_group.map { |s| s[:name] }
    assert_includes code_names, 'code_a'
    assert_includes code_names, 'code_b'

    # Find the data group (has 1 server with group key)
    data_groups = result.select { |g| g.length == 1 && g.first[:group] == 'data' }
    assert_equal 1, data_groups.length
    assert_equal 'data_a', data_groups.first.first[:name]
  end

  def test_group_with_string_keyed_group_names
    servers = [
      { name: 'server_a', "group" => 'web' },
      { name: 'server_b', "group" => 'web' }
    ]

    result = @grouper.group(servers)

    assert_equal 1, result.length
    assert_equal 2, result.first.length
  end

  def test_group_preserves_server_hashes
    server = { name: 'server_a', command: 'npx', args: ['--flag'], group: 'tools' }
    result = @grouper.group([server])

    assert_equal 1, result.length
    assert_equal server, result.first.first
  end

  def test_group_with_multiple_distinct_groups
    servers = [
      { name: 'a1', group: 'alpha' },
      { name: 'b1', group: 'beta' },
      { name: 'a2', group: 'alpha' },
      { name: 'g1', group: 'gamma' },
      { name: 'b2', group: 'beta' }
    ]

    result = @grouper.group(servers)

    assert_equal 3, result.length

    group_sizes = result.map(&:length).sort
    assert_equal [1, 2, 2], group_sizes
  end
end
