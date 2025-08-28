# lib/aia/utility.rb

require 'word_wrapper'      # Pure ruby word wrapping

module AIA
  class Utility
    class << self
      def tools?
        AIA.config&.tool_names && !AIA.config.tool_names.empty?
      end

      def user_tools?
        AIA.config&.tool_paths && !AIA.config.tool_paths.empty?
      end

      def supports_tools?
        AIA.config&.client&.model&.supports_functions? || false
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
        (_oo_)   #{AIA.config&.model || 'unknown-model'}#{supports_tools? ? ' (supports tools)' : ''}
         (O)       using #{AIA.config&.adapter || 'unknown-adapter'} (v#{RubyLLM::VERSION}#{mcp_version})
       __||__    \\) model db was last refreshed on
     [/______\\]  /    #{AIA.config&.last_refresh || 'unknown'}
    / \\__AI__/ \\/      #{user_tools? ? 'I will also use your tools' : (tools? ? 'You can share my tools' : 'I did not bring any tools')}
   /    /__\\
  (\\   /____\\   #{user_tools? && tools? ? 'My Toolbox contains:' : ''}
        ROBOT
        if user_tools? && tools?
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
