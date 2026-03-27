# lib/aia/utility.rb

require 'word_wrapper'      # Pure ruby word wrapping
require 'simple_flow'
require 'trak_flow'
require 'tty-table'
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
        return local if AIA.config&.flags&.no_mcp
        mcp   = defined?(RubyLLM::MCP) ? RubyLLM::MCP.clients.sum { |_, c| c.tools.count } : 0
        local + mcp
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
        connected = AIA.config&.connected_mcp_servers
        return connected unless connected.nil?

        # Live view from RubyLLM::MCP.clients when available
        if defined?(RubyLLM::MCP) && RubyLLM::MCP.clients.any?
          return RubyLLM::MCP.clients.keys
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

      # Displays the AIA robot ASCII art alongside status info.
      # Uses nested TTY::Tables: an inner table handles right-aligned
      # labels with word-wrapped values, placed inside an outer table
      # that keeps the ASCII art and info panel side by side.
      def robot
        art = [
          '       ,      ,',
          '       (\\____/)',
          '        (_oo_)',
          '         (O)',
          '       __|||__    \\)',
          '     [/ Tobor \\]  /',
          '    / \\_______/ \\/',
          '   /    /___\\',
          '  (\\   /_____\\',
          '     :::     :::',
          '     :::     :::',
        ].join("\n")

        art_width   = art.lines.map(&:length).max
        info_width  = [TTY::Screen.width - art_width - 4, 30].max
        label_width = 7  # "Models:" is the widest label
        value_width = [info_width - label_width - 1, 20].max

        header = "AIA v#{AIA::VERSION} is Online w/ kbs v#{KBS::VERSION}"

        inner = TTY::Table.new(banner_detail_rows)
        details = inner.render(:basic, multiline: true,
                               column_widths: [label_width, value_width],
                               alignments: [:right, :left])

        info = "#{header}\n\n#{details}"

        outer = TTY::Table.new([[art, info]])
        rendered = outer.render(:basic, multiline: true,
                                column_widths: [art_width, info_width],
                                padding: [0, 1, 0, 0])

        puts "\n#{rendered}"
      end

      private

      # Builds labeled detail rows for the banner's inner table.
      def banner_detail_rows
        [
          ['Models:', banner_models],
          ['DB:',     banner_db],
          ['Libs:',   banner_libs],
          ['Tools:',  banner_tools],
          ['MCP:',    banner_mcp],
          ['Crew:',   banner_crew],
        ]
      end

      def banner_models
        if AIA.config&.models && !AIA.config.models.empty?
          AIA.config.models.map { |spec|
            case spec
            when AIA::ModelSpec then spec.name
            when Hash then spec[:name] || spec['name'] || spec.to_s
            else spec.to_s
            end
          }.join(', ')
        else
          'unknown-model'
        end
      end

      def banner_libs
        parts = ["ruby_llm v#{RubyLLM::VERSION}"]
        parts << "ruby_llm-mcp v#{RubyLLM::MCP::VERSION}" if defined?(RubyLLM::MCP::VERSION)
        parts << "robot_lab v#{RobotLab::VERSION}" if defined?(RobotLab::VERSION)
        parts << "simple_flow v#{SimpleFlow::VERSION}" if defined?(SimpleFlow::VERSION)
        parts << "trak_flow v#{TrakFlow::VERSION}" if defined?(TrakFlow::VERSION)
        parts << "typed_bus v#{TypedBus::VERSION}" if defined?(TypedBus::VERSION)
        parts.join(', ')
      end

      def banner_tools
        count = total_tool_count
        if tools?
          "#{count} #{count == 1 ? 'tool' : 'tools'} loaded"
        else
          'none loaded'
        end
      end

      def banner_mcp
        connected = mcp_client_labels
        failed    = failed_mcp_servers.map { |f| f.is_a?(Hash) ? f[:name] || f['name'] : f.to_s }

        return '(none configured)' if connected.empty? && failed.empty?

        parts = []
        parts << connected.join(', ') unless connected.empty?
        parts << "FAILED: #{failed.join(', ')}" unless failed.empty?
        parts.join(' | ')
      end

      # Returns connected MCP client names as "name(tool_count)" strings.
      # Merges config-tracked names (AIA.config.connected_mcp_servers) with
      # RubyLLM::MCP.clients (shared_tools). Tool counts come from:
      #   1. RubyLLM::MCP.clients (shared_tools clients, live)
      #   2. AIA.config.mcp_server_tool_counts (config clients, captured at connect time)
      def mcp_client_labels
        return [] if AIA.config&.flags&.no_mcp

        names        = mcp_server_names.to_a
        ruby_llm     = defined?(RubyLLM::MCP) ? RubyLLM::MCP.clients : {}
        config_counts = AIA.config&.mcp_server_tool_counts || {}

        all_names = names | ruby_llm.keys

        all_names.map do |name|
          count = if (c = ruby_llm[name])
                    c.tools.count
                  elsif config_counts.key?(name)
                    config_counts[name]
                  end
          count ? "#{name}(#{count})" : name
        end
      end

      def banner_db
        if models_last_refresh
          "refreshed #{models_last_refresh.gsub(' ', ' at ')}"
        else
          'not yet refreshed'
        end
      end

      def banner_crew
        client = AIA.client
        return '' unless client

        names = if client.is_a?(RobotLab::Network)
                  client.robots.values.map(&:name)
                else
                  [client.name]
                end

        return '' if names.empty?
        names.map { |n| "@#{n.downcase}" }.join(', ')
      end
    end
  end
end
