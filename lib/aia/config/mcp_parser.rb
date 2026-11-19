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
    # Keys that describe how to reach the server; they go into :transport.
    TRANSPORT_KEYS = %w[type command args env url headers bearer_token oauth cwd directory].freeze

    # Server settings robot_lab understands, carried through as written.
    SERVER_KEYS = %w[prefix only except requires_approval description].freeze

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
        unless parsed.is_a?(Hash)
          warn_config(file_path, "expected a JSON object at the top level, got #{json_type(parsed)}")
          return []
        end

        if parsed.key?('mcpServers')
          convert_mcp_servers_format(parsed['mcpServers'], file_path)
        else
          convert_simple_format(parsed, file_path)
        end
      end

      # Convert mcpServers format to robot_lab nested transport format
      #
      # @param mcp_servers [Hash] the mcpServers hash from JSON
      # @param file_path [String] original file path (for warnings)
      # @return [Array<Hash>] array of server configurations
      def convert_mcp_servers_format(mcp_servers, file_path)
        unless mcp_servers.is_a?(Hash)
          warn_config(file_path, "'mcpServers' must be a JSON object, got #{json_type(mcp_servers)}")
          return []
        end

        mcp_servers.filter_map do |name, config|
          next build_server(name, config) if config.is_a?(Hash)

          $stderr.puts "Warning: Skipping MCP server '#{name}' in '#{file_path}': expected a JSON object, got #{json_type(config)}"
          nil
        end
      end

      # One server in robot_lab's format. Both JSON forms accept the same keys.
      def build_server(name, config)
        server = { name: name, transport: build_transport(config) }
        server[:timeout] = config['timeout'].to_i if config['timeout']
        SERVER_KEYS.each { |key| server[key.to_sym] = config[key] if config.key?(key) }
        server[:group] = config['group'] if config['group'] # AIA-only; read by McpGrouper
        server
      end

      # The transport hash. With no "type", a url means Streamable HTTP and
      # anything else stdio. A "command" given as an array holds the command
      # followed by its arguments.
      def build_transport(config)
        transport = config.slice(*TRANSPORT_KEYS).transform_keys(&:to_sym)
        command = transport[:command]
        if command.is_a?(Array)
          transport[:command] = command.first
          transport[:args]    = Array(command[1..]) + Array(transport[:args])
        end
        transport[:args] = Array(transport[:args]) if transport.key?(:args)
        transport[:type] ||= transport[:url] && !transport[:command] ? 'streamable-http' : 'stdio'
        transport
      end

      # Convert simple format to robot_lab nested transport format. The
      # server is named after the file ("filesystem.json" -> "filesystem").
      #
      # @param parsed [Hash] one server's settings
      # @param file_path [String] file path for deriving server name
      # @return [Array<Hash>] array with single server configuration
      def convert_simple_format(parsed, file_path)
        unless parsed['command'] || parsed['url']
          warn_config(file_path, "has neither 'mcpServers' nor a 'command' or 'url'. " \
                                 'Expected {"mcpServers": {...}} or a single server with "command" or "url"')
          return []
        end

        [build_server(File.basename(file_path, '.*'), parsed)]
      end

      def warn_config(file_path, message)
        $stderr.puts "Warning: Skipping MCP config file '#{file_path}': #{message}"
      end

      # The JSON name for a parsed value's type, for warnings.
      def json_type(value)
        case value
        when Hash              then 'an object'
        when Array             then 'an array'
        when String            then 'a string'
        when Numeric           then 'a number'
        when true, false       then 'a boolean'
        else 'null'
        end
      end
    end
  end
end
