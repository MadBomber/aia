# frozen_string_literal: true

# lib/aia/mcp_grouper.rb
#
# Groups MCP servers into independent sets that can run concurrently.
# Servers with the same `group` value must run sequentially.
# Servers without a group are each independent.

module AIA
  class MCPGrouper
    # Group MCP servers into independent sets.
    #
    # @param servers [Array<Hash>] MCP server configs
    # @return [Array<Array<Hash>>] groups of servers that can run concurrently
    def group(servers)
      return [] if servers.nil? || servers.empty?

      independent = []
      groups = Hash.new { |h, k| h[k] = [] }

      servers.each do |server|
        group_name = server[:group] || server["group"]
        if group_name
          groups[group_name] << server
        else
          independent << [server]  # Each independent server is its own group
        end
      end

      independent + groups.values
    end
  end
end
