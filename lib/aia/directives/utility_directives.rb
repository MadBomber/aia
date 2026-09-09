# lib/aia/directives/utility_directives.rb

require 'tty-screen'
require 'word_wrapper'

module AIA
  class UtilityDirectives < Directive
    desc "List available tools (optional filter by name or description substring)"
    def tools(args = [], context_manager = nil)
      raw_filter   = args.first
      loaded_tools = Array(AIA.config.loaded_tools) + all_mcp_tools

      if loaded_tools.empty?
        puts "No tools are available"
      else
        tools_to_display = filter_tools(loaded_tools, raw_filter&.downcase)
        if tools_to_display.empty?
          puts "No tools match the filter: #{raw_filter}"
        else
          print_tools_report(tools_to_display, raw_filter)
        end
      end
      puts

      ''
    end

    desc "List loaded plugin basenames"
    def plugins(args = [], context_manager = nil)
      loaded_plugins = Array(AIA.config&.loaded_plugins)

      if loaded_plugins.empty?
        puts "No plugins are loaded"
      else
        puts
        puts "Loaded Plugins"
        puts "=============="
        loaded_plugins.each { |name| puts name }
      end
      puts

      ''
    end

    desc "Show MCP server connection status and available tools"
    def mcp(args = [], context_manager = nil)
      connected = AIA.config&.connected_mcp_servers || []
      failed    = AIA.config&.failed_mcp_servers || []

      puts
      puts "MCP Server Status"
      puts "================="
      puts "Defined: #{AIA::Utility.effective_mcp_server_names.size}  " \
           "Connected: #{connected.size}  Failed: #{failed.size}"
      puts

      print_connected_servers(connected) if connected.any?
      print_failed_servers(failed) if failed.any?

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
      if client.network?
        show_network(client)
      else
        show_single_robot(client)
      end
      puts

      ''
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

    def filter_tools(tools, filter)
      return tools unless filter

      tools.select do |tool|
        "#{ToolIntrospection.tool_name(tool)} #{ToolIntrospection.tool_description(tool)}"
          .downcase.include?(filter)
      end
    end

    def print_tools_report(tools_to_display, raw_filter)
      puts
      header = raw_filter ? "Available Tools (filtered by '#{raw_filter}')" : "Available Tools"
      puts header
      puts "=" * header.length

      indent = 4
      width  = TTY::Screen.width - indent - 2
      tools_to_display.each { |tool| print_tool_entry(tool, width, " " * indent) }
    end

    def print_tool_entry(tool, width, spaces)
      name = ToolIntrospection.tool_name(tool)
      puts "\n#{name}"
      puts "-" * name.size
      puts WordWrapper::MinimumRaggedness.new(width, tool.description).wrap.split("\n").map { |s| spaces + s + "\n" }.join
    end

    def print_connected_servers(connected)
      grouped = tools_by_server(connected, all_mcp_tools)

      puts "Connected Servers:"
      connected.each do |name|
        tools = grouped[name] || []
        puts "  #{name} (#{tools.size} tools)"
        tools.each { |tool| puts "    - #{ToolIntrospection.tool_name(tool)}" }
      end
      puts
    end

    # Group MCP tools under the connected server each one came from.
    def tools_by_server(connected, mcp_tools)
      grouped = connected.to_h { |name| [name, []] }
      mcp_tools.each do |tool|
        server_name = tool.respond_to?(:mcp) ? tool.mcp : nil
        grouped[server_name] << tool if server_name && grouped.key?(server_name)
      end
      grouped
    end

    def print_failed_servers(failed)
      puts "Failed Servers:"
      failed.each do |f|
        puts "  #{f[:name] || f['name']}: #{f[:error] || f['error']}"
      end
      puts
    end

    # :reek:TooManyStatements -- mode classification plus sequential report of every crew member
    def show_network(network)
      cfg = AIA.config
      robot_count = network.robot_count
      mode = if cfg.flags.consensus
               "Consensus"
             elsif cfg.pipeline.length > 1
               "Pipeline"
             elsif cfg.models.length > 1
               "Parallel"
             else
               "Crew" # single-model session wrapped as a one-member crew
             end

      header = "Active Robots"
      puts header
      puts "=" * header.length
      noun = robot_count == 1 ? "robot" : "robots"
      puts "Mode: #{mode} (#{robot_count} #{noun})"

      network.crew.each do |bot|
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

    # :reek:TooManyStatements -- one labeled line per robot attribute (model, wage, tool counts, role)
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
      tool_parts << "#{local_count} local" if local_count.positive?
      tool_parts << "#{mcp_count} mcp" if mcp_count.positive?
      puts "    Tools:    #{total} (#{tool_parts.join(', ')})" if total.positive?
      puts "    Tools:    none" if total.zero?

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

    # Retrieve MCP tools from robot or first robot in a Network.
    # Falls back to RubyLLM::MCP.clients for tools registered by shared_tools
    # or other gems that use RubyLLM::MCP.add_client directly.
    def all_mcp_tools
      robot = AIA.client
      if robot
        if robot.respond_to?(:mcp_tools) && robot.mcp_tools&.any?
          return Array(robot.mcp_tools)
        end

        first_robot = robot.chief
        if first_robot.respond_to?(:mcp_tools) && first_robot.mcp_tools&.any?
          return Array(first_robot.mcp_tools)
        end
      end

      # Fall back to RubyLLM::MCP clients (shared_tools and other gems
      # that register MCP servers via RubyLLM::MCP.add_client)
      return [] unless defined?(RubyLLM::MCP)
      RubyLLM::MCP.clients.values.flat_map(&:tools)
    end
  end
end
