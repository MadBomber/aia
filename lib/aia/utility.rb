# lib/aia/utility.rb

require 'word_wrapper'      # Pure ruby word wrapping

module AIA
  class Utility
    class << self
      def tools?
        AIA.config&.tool_names && !AIA.config.tool_names.empty?
      end

      def user_tools?
        AIA.config&.tools&.paths && !AIA.config.tools.paths.empty?
      end

      def mcp_servers?
        names = effective_mcp_server_names
        !names.empty?
      end

      # Returns MCP server names the robot is configured to use.
      # After first run, returns actually connected server names.
      def mcp_server_names
        # After first run, robot has actual connection info
        robot = AIA.client
        if robot&.respond_to?(:mcp_clients) && !robot.mcp_clients.empty?
          return robot.mcp_clients.keys
        end

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

      # Displays the AIA robot ASCII art
      # Yes, its slightly frivolous but it does contain some
      # useful configuration information.
      def robot
        indent  = 18
        spaces  = " "*indent
        width   = TTY::Screen.width - indent - 2

        mcp_version = defined?(RubyLLM::MCP::VERSION) ? " MCP v" + RubyLLM::MCP::VERSION : ''

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

        # Build MCP line showing configured servers
        mcp_line = if mcp_servers?
          "MCP: #{mcp_server_names.join(', ')}"
        else
          "MCP: (none configured)"
        end

        puts <<-ROBOT

       ,      ,
       (\\____/) AI Assistant (v#{AIA::VERSION}) is Online
        (_oo_)   #{model_display}#{supports_tools? ? ' (supports tools)' : ''}
         (O)       using ruby_llm (v#{RubyLLM::VERSION}#{mcp_version})
       __||__    \\) model db was last refreshed on
     [/______\\]  /    #{models_last_refresh || 'unknown'}
    / \\__AI__/ \\/      #{user_tools? ? 'I will also use your tools' : (tools? ? 'You can share my tools' : 'I did not bring any tools')}
   /    /__\\              #{mcp_line}
  (\\   /____\\   #{user_tools? && tools? ? 'My Toolbox contains:' : ''}
        ROBOT
        if user_tools? && tools?
          tool_names = AIA.config.tool_names
          if tool_names && !tool_names.to_s.empty?
            puts WordWrapper::MinimumRaggedness.new(
                width,
                tool_names.to_s # String of tool names, comma separated
              ).wrap
              .split("\n")
              .map{|s| spaces+s+"\n"}
              .join
          end
        end
      end
    end
  end
end
