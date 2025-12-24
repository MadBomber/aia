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
        AIA.config&.mcp_servers && !AIA.config.mcp_servers.empty?
      end

      # Returns only successfully connected MCP server names
      def mcp_server_names
        # Use connected_mcp_servers if available (populated during MCP setup)
        connected = AIA.config&.connected_mcp_servers
        return connected if connected && !connected.empty?

        # Fallback to configured servers if connection status not yet known
        return [] unless mcp_servers?
        AIA.config.mcp_servers.map { |s| s[:name] || s["name"] }.compact
      end

      # Returns true if there are any connected MCP servers
      def connected_mcp_servers?
        connected = AIA.config&.connected_mcp_servers
        connected && !connected.empty?
      end

      # Returns list of failed MCP servers with their errors
      def failed_mcp_servers
        AIA.config&.failed_mcp_servers || []
      end

      def supports_tools?
        AIA.client&.model&.supports_functions? || false
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

        # Extract model names from config (handles ModelSpec objects from ADR-005)
        model_display = if AIA.config&.models && !AIA.config.models.empty?
          models = AIA.config.models
          models.map { |spec| spec.respond_to?(:name) ? spec.name : spec.to_s }.join(', ')
        else
          'unknown-model'
        end

        # Build MCP line based on connection status
        mcp_line = if !mcp_servers?
          ''  # No MCP servers configured
        elsif connected_mcp_servers?
          "MCP: #{mcp_server_names.join(', ')}"
        else
          "MCP: (none connected)"
        end

        puts <<-ROBOT

       ,      ,
       (\\____/) AI Assistant (v#{AIA::VERSION}) is Online
        (_oo_)   #{model_display}#{supports_tools? ? ' (supports tools)' : ''}
         (O)       using #{AIA.config&.llm&.adapter || 'unknown-adapter'} (v#{RubyLLM::VERSION}#{mcp_version})
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
