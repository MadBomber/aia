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

    desc "Show active robot configuration"
    def robots(args = [], context_manager = nil)
      client = AIA.client
      unless client
        puts "No active robots"
        return ''
      end

      puts
      if client.is_a?(RobotLab::Network)
        show_network(client)
      else
        show_single_robot(client)
      end
      puts

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

    def show_network(network)
      robot_count = network.robots.size
      mode = if AIA.config.flags.consensus
               "Consensus"
             elsif AIA.config.pipeline.length > 1
               "Pipeline"
             else
               "Parallel"
             end

      header = "Active Robots"
      puts header
      puts "=" * header.length
      puts "Mode: #{mode} Network (#{robot_count} robots)"

      network.robots.each_value do |bot|
        puts
        show_robot_detail(bot)
      end
    end

    def show_single_robot(bot)
      header = "Active Robot"
      puts header
      puts "=" * header.length
      puts "Mode: Single"
      puts
      show_robot_detail(bot)
    end

    def show_robot_detail(bot)
      puts "  #{bot.name}"

      model_name = bot.model || 'unknown'
      provider = bot.respond_to?(:provider) ? bot.provider : nil
      provider ||= chat_provider(bot)
      model_line = provider ? "#{model_name} (#{provider})" : model_name
      puts "    Model:    #{model_line}"
      puts "    Wage:     #{wage_for(model_name)}"

      local_count = Array(bot.local_tools).size
      mcp_count = Array(bot.mcp_tools).size
      total = local_count + mcp_count
      tool_parts = []
      tool_parts << "#{local_count} local" if local_count > 0
      tool_parts << "#{mcp_count} mcp" if mcp_count > 0
      puts "    Tools:    #{total} (#{tool_parts.join(', ')})" if total > 0
      puts "    Tools:    none" if total == 0

      role = role_for(bot)
      puts "    Role:     #{role}"
    end

    # Cost per 1K tokens (price_per_million * 1000 / 1_000_000)
    def wage_for(model_name)
      model_info = RubyLLM::Models.find(model_name)
      input  = model_info&.input_price_per_million
      output = model_info&.output_price_per_million
      return 'N/A' unless input && output

      in_per_k  = input  * 1000.0 / 1_000_000
      out_per_k = output * 1000.0 / 1_000_000
      "$#{'%.4f' % in_per_k} in / $#{'%.4f' % out_per_k} out per 1K tokens"
    rescue StandardError
      'N/A'
    end

    def chat_provider(bot)
      bot.chat_provider
    rescue StandardError
      nil
    end

    def role_for(bot)
      spec = AIA.config.models.find { |s| s.name == bot.model }
      if spec&.role?
        spec.role
      else
        "(default)"
      end
    end

    # Retrieve MCP tools from robot or first robot in a Network
    def all_mcp_tools
      robot = AIA.client
      return [] unless robot

      return Array(robot.mcp_tools) if robot.respond_to?(:mcp_tools)

      if robot.respond_to?(:robots) && robot.robots.is_a?(Hash)
        first_robot = robot.robots.values.first
        return Array(first_robot.mcp_tools) if first_robot
      end

      []
    end
  end
end
