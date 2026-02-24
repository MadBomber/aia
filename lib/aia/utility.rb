# lib/aia/utility.rb

require 'word_wrapper'      # Pure ruby word wrapping
require 'simple_flow'
require 'trak_flow'
begin
  require 'ruby_llm/mcp'
rescue LoadError, StandardError
  # ruby_llm-mcp may not be installed
end

module AIA
  class Utility
    class << self
      def tools?
        return true if AIA.config&.tool_names && !AIA.config.tool_names.empty?
        total_tool_count > 0
      end

      # Total count of all available tools (local + MCP)
      def total_tool_count
        local = Array(AIA.config&.loaded_tools).size
        mcp   = mcp_tool_count
        local + mcp
      end

      # Count MCP tools from the robot or first robot in a Network
      def mcp_tool_count
        robot = AIA.client
        return 0 unless robot

        # Single robot with mcp_tools
        if robot.respond_to?(:mcp_tools)
          return Array(robot.mcp_tools).size
        end

        # Network: check instance variable on first robot
        if robot.respond_to?(:robots) && robot.robots.is_a?(Hash)
          first_robot = robot.robots.values.first
          if first_robot
            tools = first_robot.instance_variable_get(:@mcp_tools)
            return Array(tools).size
          end
        end

        0
      end

      def user_tools?
        AIA.config&.tools&.paths && !AIA.config.tools.paths.empty?
      end

      def mcp_servers?
        names = effective_mcp_server_names
        !names.empty?
      end

      # Returns MCP server names that are actually connected.
      # Returns [] when connection was attempted but none succeeded.
      # Falls back to configured names only before connection is attempted.
      def mcp_server_names
        # If early connection was attempted, return its result (even if empty)
        connected = AIA.config&.connected_mcp_servers
        return connected unless connected.nil?

        # Check the robot's actual client connections
        robot = AIA.client
        if robot&.respond_to?(:mcp_clients) && !robot.mcp_clients.empty?
          return robot.mcp_clients.keys
        end

        # Pre-connection fallback: return configured names
        effective_mcp_server_names
      end

      # Returns true if there are MCP servers configured for the robot
      def connected_mcp_servers?
        !mcp_server_names.empty?
      end

      # Returns list of failed MCP servers with their errors
      def failed_mcp_servers
        AIA.config&.failed_mcp_servers || []
      end

      # Returns server names after applying --mcp-use / --mcp-skip / --no-mcp filters
      def effective_mcp_server_names
        return [] if AIA.config&.flags&.no_mcp

        servers = AIA.config&.mcp_servers || []
        return [] if servers.empty?

        use_list  = Array(AIA.config.mcp_use)
        skip_list = Array(AIA.config.mcp_skip)

        if !use_list.empty?
          servers = servers.select { |s| use_list.include?(server_name(s)) }
        elsif !skip_list.empty?
          servers = servers.reject { |s| skip_list.include?(server_name(s)) }
        end

        servers.map { |s| server_name(s) }.compact
      end

      # Extract name from a server config (Hash with string or symbol keys, or object)
      def server_name(s)
        if s.is_a?(Hash)
          s[:name] || s['name']
        elsif s.respond_to?(:name)
          s.name
        else
          s.to_s
        end
      end

      def supports_tools?
        robot = AIA.client
        return false unless robot

        # In v2, AIA.client is a RobotLab::Robot
        if robot.respond_to?(:model)
          model = robot.model
          if model.respond_to?(:supports_functions?)
            model.supports_functions?
          else
            false
          end
        else
          false
        end
      end

      # Returns the last refresh date from models.json modification time
      def models_last_refresh
        aia_dir = AIA.config&.paths&.aia_dir
        return nil if aia_dir.nil?

        models_file = File.join(File.expand_path(aia_dir), 'models.json')
        return nil unless File.exist?(models_file)

        File.mtime(models_file).strftime('%Y-%m-%d %H:%M')
      end

      # Build the "Today's crew:" line from robot names
      def build_crew_line
        client = AIA.client
        return '' unless client

        names = if client.is_a?(RobotLab::Network)
                  client.robots.values.map(&:name)
                else
                  [client.name]
                end

        return '' if names.empty?

        mentions = names.map { |n| "@#{n.downcase}" }.join(', ')
        "Today's crew: #{mentions}"
      end

      # Displays the AIA robot ASCII art
      # Yes, its slightly frivolous but it does contain some
      # useful configuration information.
      def robot
        indent  = 18
        spaces  = " "*indent
        width   = TTY::Screen.width - indent - 2

        mcp_version = defined?(RubyLLM::MCP::VERSION) ? ", ruby_llm-mcp v#{RubyLLM::MCP::VERSION}" : ''

        # Build orchestration gems version line
        orchestration_parts = []
        orchestration_parts << "robot_lab v#{RobotLab::VERSION}" if defined?(RobotLab::VERSION)
        orchestration_parts << "simple_flow v#{SimpleFlow::VERSION}" if defined?(SimpleFlow::VERSION)
        orchestration_parts << "trak_flow v#{TrakFlow::VERSION}" if defined?(TrakFlow::VERSION)
        orchestration_line = orchestration_parts.join(', ')

        # Extract model names from config (handles ModelSpec objects or Hashes)
        model_display = if AIA.config&.models && !AIA.config.models.empty?
          models = AIA.config.models
          models.map do |spec|
            if spec.is_a?(AIA::ModelSpec)
              spec.name
            elsif spec.is_a?(Hash)
              spec[:name] || spec['name'] || spec.to_s
            else
              spec.to_s
            end
          end.join(', ')
        else
          'unknown-model'
        end

        # Build MCP line showing connection status
        mcp_line = if mcp_servers?
          defined_count   = effective_mcp_server_names.size
          connected       = mcp_server_names
          failed          = failed_mcp_servers
          connected_count = connected.size
          failed_count    = failed.size
          "MCP Servers defined: #{defined_count}  Connected: #{connected_count}  Failed: #{failed_count}"
        else
          "MCP Servers: (none configured)"
        end

        model_db_refresh = "model db "
        model_db_refresh += if models_last_refresh
                              "was last refreshed on #{models_last_refresh.gsub(' ',' at ')}"
                            else
                              "has not been refreshed"
                            end

        # Build crew line from robot names
        crew_line = build_crew_line

        puts <<-ROBOT

       ,      ,
       (\\____/) AI Assistant (v#{AIA::VERSION}) is Online with kbs (v#{KBS::VERSION})
        (_oo_)   #{model_display}#{supports_tools? ? ' (supports tools)' : ''}
         (O)       using ruby_llm v#{RubyLLM::VERSION}#{mcp_version}
       __||__    \\)   #{orchestration_line}
     [/______\\]  /   #{model_db_refresh}
    / \\__AI__/ \\/      #{tools? ? "I brought #{total_tool_count} tools to share" : 'I did not bring any tools'}
   /    /__\\              #{mcp_line}
  (\\   /____\\           #{crew_line}
        ROBOT
      end
    end
  end
end
