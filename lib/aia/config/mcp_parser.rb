# frozen_string_literal: true

# lib/aia/config/mcp_parser.rb
#
# Parses MCP server JSON configuration files and converts them
# to the nested transport format expected by robot_lab.
#
# Output format (robot_lab native):
#   {
#     name: "server_name",
#     transport: { type: "stdio", command: "npx", args: [...], env: {...} },
#     timeout: 8000,
#     topics: ["routing"],     # AIA routing metadata (optional)
#     independent: false,      # AIA concurrency metadata (optional)
#     group: "services"        # AIA grouping metadata (optional)
#   }
#
# Supports two JSON input formats:
#
# 1. Simple format (single server):
#    {
#      "type": "stdio",
#      "command": ["npx", "-y", "@server/name", "/path"]
#    }
#
# 2. mcpServers format (one or more servers):
#    {
#      "mcpServers": {
#        "server_name": {
#          "command": "python",
#          "args": ["-m", "module_name"],
#          "env": {},
#          "timeout": 8000
#        }
#      }
#    }

require 'json'

module AIA
  module McpParser
    class << self
      # Parse MCP server configuration files and return array of server configs
      # in robot_lab's nested transport format.
      #
      # @param file_paths [Array<String>] paths to JSON configuration files
      # @return [Array<Hash>] array of server configurations with nested transport
      def parse_files(file_paths)
        return [] if file_paths.nil? || file_paths.empty?

        servers = []

        file_paths.each do |file_path|
          expanded_path = File.expand_path(file_path)

          unless File.exist?(expanded_path)
            warn "Warning: MCP config file not found: #{file_path}"
            next
          end

          begin
            json_content = File.read(expanded_path)
            parsed = JSON.parse(json_content)
            servers.concat(convert_to_config_format(parsed, file_path))
          rescue JSON::ParserError => e
            warn "Warning: Invalid JSON in MCP config file '#{file_path}': #{e.message}"
          rescue StandardError => e
            warn "Warning: Error reading MCP config file '#{file_path}': #{e.message}"
          end
        end

        servers
      end

      private

      # Convert parsed JSON to the config format
      #
      # @param parsed [Hash] parsed JSON content
      # @param file_path [String] original file path (for deriving server name)
      # @return [Array<Hash>] array of server configurations
      def convert_to_config_format(parsed, file_path)
        if parsed.key?('mcpServers')
          convert_mcp_servers_format(parsed['mcpServers'])
        else
          convert_simple_format(parsed, file_path)
        end
      end

      # Convert mcpServers format to robot_lab nested transport format
      #
      # @param mcp_servers [Hash] the mcpServers hash from JSON
      # @return [Array<Hash>] array of server configurations
      def convert_mcp_servers_format(mcp_servers)
        mcp_servers.map do |name, config|
          transport = { type: config['type'] || 'stdio' }
          transport[:command] = config['command'] if config['command']
          transport[:args]    = Array(config['args']) if config['args']
          transport[:env]     = config['env'] if config['env']
          transport[:url]     = config['url'] if config['url']
          transport[:headers] = config['headers'] if config['headers']

          server = { name: name, transport: transport }
          server[:timeout] = config['timeout'].to_i if config['timeout']

          # Preserve routing metadata for KBS/AIA
          server[:topics]      = Array(config['topics']) if config['topics']
          server[:independent] = config['independent'] if config['independent'] != nil
          server[:group]       = config['group'] if config['group']

          server
        end
      end

      # Convert simple format to robot_lab nested transport format
      #
      # @param parsed [Hash] parsed JSON with type and command
      # @param file_path [String] file path for deriving server name
      # @return [Array<Hash>] array with single server configuration
      def convert_simple_format(parsed, file_path)
        # Derive name from filename (e.g., "filesystem.json" -> "filesystem")
        name = File.basename(file_path, '.*')

        transport = { type: parsed['type'] || 'stdio' }

        if parsed['command'].is_a?(Array)
          # Command is an array: first element is command, rest are args
          transport[:command] = parsed['command'].first
          transport[:args] = parsed['command'][1..] || []
        elsif parsed['command']
          transport[:command] = parsed['command']
          transport[:args] = parsed['args'] || []
        end

        transport[:env] = parsed['env'] if parsed['env']

        server = { name: name, transport: transport }
        server[:timeout] = parsed['timeout'].to_i if parsed['timeout']

        [server]
      end
    end
  end
end
