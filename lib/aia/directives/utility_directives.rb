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

      loaded_tools = AIA.config.loaded_tools || []
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
  end
end
