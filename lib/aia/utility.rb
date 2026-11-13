# lib/aia/utility.rb

require 'word_wrapper'
require 'simple_flow'
require 'trak_flow'
require 'tty-table'
require_relative 'mcp_utility'
require_relative 'tool_utility'

module AIA
  module Utility
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
          '     :::     :::'
        ].join("\n")

        art_width   = art.lines.map(&:length).max
        info_width  = [TTY::Screen.width - art_width - 4, 30].max
        label_width = 7  # "Models:" is the widest label
        value_width = [info_width - label_width - 1, 20].max

        header = "AIA v#{AIA::VERSION} is Online"

        inner = TTY::Table.new(banner_detail_rows)
        details = inner.render(:basic, multiline: true,
                               column_widths: [label_width, value_width],
                               alignments: %i[right left])

        outer = TTY::Table.new([[art, "#{header}\n\n#{details}"]])
        puts "\n#{outer.render(:basic, multiline: true, column_widths: [art_width, info_width], padding: [0, 1, 0, 0])}"
      end

      private

      def robot_names
        client = AIA.client
        return [] unless client
        client.crew.map(&:name)
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
          ['Crew:',   banner_crew]
        ]
      end

      def banner_models
        models = AIA.config&.models
        return 'unknown-model' if models.nil? || models.empty?
        models.map do |spec|
          case spec
          when AIA::ModelSpec then spec.name
          when Hash           then spec[:name] || spec['name'] || spec.to_s
          else                     spec.to_s
          end
        end.join(', ')
      end

      def banner_libs
        parts = ["ruby_llm v#{RubyLLM::VERSION}"]
        parts << "robot_lab v#{RobotLab::VERSION}"         if defined?(RobotLab::VERSION)
        parts << "simple_flow v#{SimpleFlow::VERSION}"     if defined?(SimpleFlow::VERSION)
        parts << "trak_flow v#{TrakFlow::VERSION}"         if defined?(TrakFlow::VERSION)
        parts << "typed_bus v#{TypedBus::VERSION}"         if defined?(TypedBus::VERSION)
        parts.join(', ')
      end

      def banner_tools
        count = total_tool_count
        if count.positive?
          "#{count} #{count == 1 ? 'tool' : 'tools'} loaded"
        else
          'none loaded'
        end
      end

      def banner_mcp
        connected = mcp_client_labels
        failed    = failed_mcp_servers.map { |f| server_name(f) }
        return '(none configured)' if connected.empty? && failed.empty?
        parts = []
        parts << connected.join(', ')           unless connected.empty?
        parts << "FAILED: #{failed.join(', ')}" unless failed.empty?
        parts.join(' | ')
      end

      # connected_mcp_servers (set by MCPConnectionManager) is the authoritative
      # name list; mcp_server_tool_counts provides per-server tool counts.
      def mcp_client_labels
        cfg = AIA.config
        return [] if cfg&.flags&.no_mcp

        counts = cfg&.mcp_server_tool_counts || {}
        Array(cfg&.connected_mcp_servers).map do |name|
          count = counts[name]
          count ? "#{name}(#{count})" : name
        end
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

      public

      # Token usage for one LLM result, or nil when the result reports none.
      #
      # RobotLab::RobotResult carries the counts directly. Under ruby_llm 2.x
      # the raw RubyLLM::Message keeps them under #tokens, not #input_tokens.
      #
      # @return [Hash, nil] { input_tokens:, output_tokens:, model_id: }
      def token_usage(result)
        raw = result.respond_to?(:raw) ? result.raw : nil
        input, output = token_counts(result, raw)
        return nil if input.zero? && output.zero?

        { input_tokens: input, output_tokens: output, model_id: raw_model_id(raw) }
      end

      private

      def token_counts(result, raw)
        if result.respond_to?(:input_tokens)
          [result.input_tokens.to_i, (result.respond_to?(:output_tokens) ? result.output_tokens : 0).to_i]
        elsif raw.respond_to?(:tokens) && (tokens = raw.tokens)
          [tokens.input.to_i, tokens.output.to_i]
        elsif raw.respond_to?(:input_tokens)
          [raw.input_tokens.to_i, (raw.respond_to?(:output_tokens) ? raw.output_tokens : 0).to_i]
        else
          [0, 0]
        end
      end

      def raw_model_id(raw)
        return raw.model_id if raw.respond_to?(:model_id) && raw.model_id
        return raw.model    if raw.respond_to?(:model)    && raw.model

        nil
      end
    end
  end
end
