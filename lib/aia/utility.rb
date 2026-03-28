# lib/aia/utility.rb

require 'word_wrapper'
require 'simple_flow'
require 'trak_flow'
require 'tty-table'
begin
  require 'ruby_llm/mcp'
rescue LoadError, StandardError
  # ruby_llm-mcp may not be installed
end

require_relative 'mcp_utility'
require_relative 'tool_utility'

module AIA
  class Utility
    class << self
      include MCPUtility
      include ToolUtility

      def models_last_refresh
        aia_dir = AIA.config&.paths&.aia_dir
        return nil if aia_dir.nil?
        models_file = File.join(File.expand_path(aia_dir), 'models.json')
        File.mtime(models_file).strftime('%Y-%m-%d %H:%M')
      rescue Errno::ENOENT
        nil
      end

      def build_crew_line
        names = robot_names
        return '' if names.empty?
        "Today's crew: #{format_crew_mentions(names)}"
      end

      def robot
        art = [
          '       ,      ,',
          '       (\____/)',
          '        (_oo_)',
          '         (O)',
          '       __|||__    \)',
          '     [/ Tobor \]  /',
          '    / \_______/ \/',
          '   /    /___\\',
          '  (\   /_____\\',
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

        outer = TTY::Table.new([[art, "#{header}\n\n#{details}"]])
        puts "\n#{outer.render(:basic, multiline: true, column_widths: [art_width, info_width], padding: [0, 1, 0, 0])}"
      end

      private

      def robot_names
        client = AIA.client
        return [] unless client
        client.is_a?(RobotLab::Network) ? client.robots.values.map(&:name) : [client.name]
      end

      def format_crew_mentions(names)
        names.map { |n| "@#{n.downcase}" }.join(', ')
      end

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
        models = AIA.config&.models
        return 'unknown-model' if models.nil? || models.empty?
        models.map { |spec|
          case spec
          when AIA::ModelSpec then spec.name
          when Hash           then spec[:name] || spec['name'] || spec.to_s
          else                     spec.to_s
          end
        }.join(', ')
      end

      def banner_libs
        parts = ["ruby_llm v#{RubyLLM::VERSION}"]
        parts << "ruby_llm-mcp v#{RubyLLM::MCP::VERSION}" if defined?(RubyLLM::MCP::VERSION)
        parts << "robot_lab v#{RobotLab::VERSION}"         if defined?(RobotLab::VERSION)
        parts << "simple_flow v#{SimpleFlow::VERSION}"     if defined?(SimpleFlow::VERSION)
        parts << "trak_flow v#{TrakFlow::VERSION}"         if defined?(TrakFlow::VERSION)
        parts << "typed_bus v#{TypedBus::VERSION}"         if defined?(TypedBus::VERSION)
        parts.join(', ')
      end

      def banner_db
        refresh = models_last_refresh
        refresh ? "refreshed #{refresh.gsub(' ', ' at ')}" : 'not yet refreshed'
      end

      def banner_crew
        names = robot_names
        return '' if names.empty?
        format_crew_mentions(names)
      end
    end
  end
end
