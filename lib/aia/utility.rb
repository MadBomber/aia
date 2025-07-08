# lib/aia/utility.rb

require 'word_wrapper'      # Pure ruby word wrapping

module AIA
  class Utility
    class << self
      def tools?
        !AIA.config.tool_names.empty?
      end

      def supports_tools?
        AIA.config.client.model.supports_functions?
      end


      # Displays the AIA robot ASCII art
      # Yes, its slightly frivolous but it does contain some
      # useful configuration information.
      def robot
        indent  = 18
        spaces  = " "*indent
        width   = TTY::Screen.width - indent - 2

        mcp_version = defined?(RubyLLM::MCP::VERSION) ? " MCP v" + RubyLLM::MCP::VERSION : ''

        puts <<-ROBOT

       ,      ,
       (\\____/) AI Assistant (v#{AIA::VERSION}) is Online
        (_oo_)   #{AIA.config.model}#{supports_tools? ? ' (supports tools)' : ''}
         (O)       using #{AIA.config.adapter} (v#{RubyLLM::VERSION}#{mcp_version})
       __||__    \\) model db was last refreshed on
     [/______\\]  /    #{AIA.config.last_refresh}
    / \\__AI__/ \\/      #{tools? ? 'You can share my tools' : 'I did not bring any tools'}
   /    /__\\
  (\\   /____\\   #{tools? ? 'My Toolbox contains:' : ''}
        ROBOT
        if tools?
          tool_names = AIA.config.respond_to?(:tool_names) ? AIA.config.tool_names : AIA.config.tools
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
