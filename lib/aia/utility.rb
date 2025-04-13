# lib/aia/utility.rb

module AIA
  class Utility
    class << self
      # Displays the AIA robot ASCII art
      def robot
        puts <<-ROBOT

       ,      ,
       (\\____/) AI Assistant
        (_oo_)   #{AIA.config.model}
         (O)      is Online
       __||__    \\)
     [/______\\]  /
    / \\__AI__/ \\/
   /    /__\\
  (\\   /____\\

        ROBOT
      end
    end
  end
end
