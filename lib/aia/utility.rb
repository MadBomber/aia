# lib/aia/utility.rb

require 'word_wrapper'      # Pure ruby word wrapping

module AIA
  class Utility
    class << self
      # Displays the AIA robot ASCII art
      # Yes, its slightly frivolous but it does contain some
      # useful configuration information.
      def robot
        indent  = 18
        spaces  = " "*indent
        width   = TTY::Screen.width - indent - 2

        puts <<-ROBOT

       ,      ,
       (\\____/) AI Assistant (v#{AIA::VERSION}) is Online
        (_oo_)   #{AIA.config.model}
         (O)       using #{AIA.config.adapter} (v#{RubyLLM::VERSION})
       __||__    \\) model db was last refreshed on
     [/______\\]  /    #{AIA.config.last_refresh}
    / \\__AI__/ \\/      #{AIA.config.tool_paths.empty? ? 'You can share my tools' : 'I will also use your tools'}
   /    /__\\
  (\\   /____\\   #{AIA.config.tool_paths.empty? ? '' : 'My Toolbox contains:'}
        ROBOT
        if AIA.config.tools
          puts WordWrapper::MinimumRaggedness.new(width, AIA.config.tools).wrap.split("\n").map{|s| spaces+s+"\n"}.join
        end
      end
    end
  end
end
