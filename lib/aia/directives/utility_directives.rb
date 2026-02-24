# lib/aia/directives/utility_directives.rb

require 'tty-screen'
require 'word_wrapper'

module AIA
  class UtilityDirectives < Directive
    desc "List available tools (optional filter by name substring)"
    def tools(args = [], context_manager = nil)
      indent = 4
      spaces = " " * indent
      width = TTY::Screen.width - indent - 2
      filter = args.first&.downcase

      loaded_tools = Array(AIA.config.loaded_tools) + all_mcp_tools

      if loaded_tools.empty?
        puts "No tools are available"
      else
        tools_to_display = loaded_tools

        if filter
          tools_to_display = tools_to_display.select do |tool|
            name = tool.respond_to?(:name) ? tool.name : tool.class.name
            name.downcase.include?(filter)
          end
        end

        if tools_to_display.empty?
          puts "No tools match the filter: #{args.first}"
        else
          puts
          header = filter ? "Available Tools (filtered by '#{args.first}')" : "Available Tools"
          puts header
          puts "=" * header.length

          tools_to_display.each do |tool|
            name = tool.respond_to?(:name) ? tool.name : tool.class.name
            puts "\n#{name}"
            puts "-" * name.size
            puts WordWrapper::MinimumRaggedness.new(width, tool.description).wrap.split("\n").map { |s| spaces + s + "\n" }.join
          end
        end
      end
      puts

      ''
    end

    desc "Show MCP server connection status and available tools"
    def mcp(args = [], context_manager = nil)
      connected = AIA.config&.connected_mcp_servers || []
      failed    = AIA.config&.failed_mcp_servers || []
      defined_count = AIA::Utility.effective_mcp_server_names.size

      puts
      puts "MCP Server Status"
      puts "================="
      puts "Defined: #{defined_count}  Connected: #{connected.size}  Failed: #{failed.size}"
      puts

      if connected.any?
        mcp_tools = all_mcp_tools

        # Group tools by their MCP server name
        tools_by_server = {}
        connected.each { |name| tools_by_server[name] = [] }

        mcp_tools.each do |tool|
          server_name = tool.respond_to?(:mcp) ? tool.mcp : nil
          if server_name && tools_by_server.key?(server_name)
            tools_by_server[server_name] << tool
          end
        end

        puts "Connected Servers:"
        connected.each do |name|
          tools = tools_by_server[name] || []
          puts "  #{name} (#{tools.size} tools)"
          tools.each do |tool|
            tool_name = tool.respond_to?(:name) ? tool.name : tool.class.name
            puts "    - #{tool_name}"
          end
        end
        puts
      end

      if failed.any?
        puts "Failed Servers:"
        failed.each do |f|
          name  = f[:name] || f['name']
          error = f[:error] || f['error']
          puts "  #{name}: #{error}"
        end
        puts
      end

      ''
    end

    desc "Add instruction for concise responses"
    def terse(args, context_manager = nil)
      "" # DEPRECATED: terse mode has been removed
    end

    desc "Display ASCII robot art"
    def robot(args, context_manager = nil)
      AIA::Utility.robot
      ""
    end

    desc "Show this help message"
    def help(args = nil, context_manager = nil)
      AIA::Directive.help
    end

    private

    # Retrieve MCP tools from robot or first robot in a Network
    def all_mcp_tools
      robot = AIA.client
      return [] unless robot

      if robot.respond_to?(:mcp_tools)
        return Array(robot.mcp_tools)
      end

      if robot.respond_to?(:robots) && robot.robots.is_a?(Hash)
        first_robot = robot.robots.values.first
        if first_robot
          tools = first_robot.instance_variable_get(:@mcp_tools)
          return Array(tools)
        end
      end

      []
    end
  end
end
