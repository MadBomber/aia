# frozen_string_literal: true

# lib/aia/config/mcp_parser.rb
#
# Parses MCP server JSON configuration files and converts them
# to the format expected by AIA's config system.
#
# Supports two JSON formats:
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
      #
      # @param file_paths [Array<String>] paths to JSON configuration files
      # @return [Array<Hash>] array of server configurations
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

      # Convert mcpServers format to config format
      #
      # @param mcp_servers [Hash] the mcpServers hash from JSON
      # @return [Array<Hash>] array of server configurations
      def convert_mcp_servers_format(mcp_servers)
        mcp_servers.map do |name, config|
          server = { name: name }

          if config['command']
            server[:command] = config['command']
          end

          if config['args']
            server[:args] = Array(config['args'])
          end

          if config['env']
            server[:env] = config['env']
          end

          if config['timeout']
            server[:timeout] = config['timeout'].to_i
          end

          if config['url']
            server[:url] = config['url']
          end

          if config['headers']
            server[:headers] = config['headers']
          end

          server
        end
      end

      # Convert simple format to config format
      #
      # @param parsed [Hash] parsed JSON with type and command
      # @param file_path [String] file path for deriving server name
      # @return [Array<Hash>] array with single server configuration
      def convert_simple_format(parsed, file_path)
        # Derive name from filename (e.g., "filesystem.json" -> "filesystem")
        name = File.basename(file_path, '.*')

        server = { name: name }

        if parsed['command'].is_a?(Array)
          # Command is an array: first element is command, rest are args
          server[:command] = parsed['command'].first
          server[:args] = parsed['command'][1..] || []
        elsif parsed['command']
          server[:command] = parsed['command']
          server[:args] = parsed['args'] || []
        end

        if parsed['env']
          server[:env] = parsed['env']
        end

        if parsed['timeout']
          server[:timeout] = parsed['timeout'].to_i
        end

        if parsed['type']
          server[:type] = parsed['type']
        end

        [server]
      end
    end
  end
end
