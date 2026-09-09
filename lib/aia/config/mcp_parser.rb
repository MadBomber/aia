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
      # :reek:TooManyStatements -- per-file loop with warn-and-continue handling for missing files, bad JSON, and read errors
      def parse_files(file_paths)
        return [] if file_paths.nil? || file_paths.empty?

        servers = []

        file_paths.each do |file_path|
          expanded_path = File.expand_path(file_path)

          unless File.exist?(expanded_path)
            $stderr.puts "Warning: MCP config file not found: #{file_path}"
            next
          end

          begin
            json_content = File.read(expanded_path)
            parsed = JSON.parse(json_content)
            servers.concat(convert_to_config_format(parsed, file_path))
          rescue JSON::ParserError => e
            $stderr.puts "Warning: Invalid JSON in MCP config file '#{file_path}': #{e.message}"
          rescue StandardError => e
            $stderr.puts "Warning: Error reading MCP config file '#{file_path}': #{e.message}"
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
          server = { name: name, transport: build_transport(config) }
          server[:timeout] = config['timeout'].to_i if config['timeout']
          server.merge!(routing_metadata(config))
        end
      end

      def build_transport(config)
        transport = { type: config['type'] || 'stdio' }
        transport[:command] = config['command'] if config['command']
        transport[:args]    = Array(config['args']) if config['args']
        transport[:env]     = config['env'] if config['env']
        transport[:url]     = config['url'] if config['url']
        transport[:headers] = config['headers'] if config['headers']
        transport
      end

      # Routing metadata preserved for KBS/AIA
      def routing_metadata(config)
        meta = {}
        meta[:topics]      = Array(config['topics']) if config['topics']
        meta[:independent] = config['independent'] unless config['independent'].nil?
        meta[:group]       = config['group'] if config['group']
        meta
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

        command = parsed['command']
        if command.is_a?(Array)
          # Command is an array: first element is command, rest are args
          transport[:command] = command.first
          transport[:args] = command[1..] || []
        elsif command
          transport[:command] = command
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
