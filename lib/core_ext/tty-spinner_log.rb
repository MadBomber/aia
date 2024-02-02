# aia/lib/core_ext/tty-spinner_log.rb
#
# The gem's README shows the log method; bit the
# author has been spinning his wheels since 2021 on pushing a release
# with it.  This is a stop gap.

module TTY
  class Spinner
    # Log a message to the output
    # This will clear the current spinner line, print the log message,
    # and then redraw or resume the spinner on a new line.
    #
    # @param [String] message
    #   the log message to print
    #
    # @api public
    def log(message)
      synchronize do
        clear_line    # Clear the spinner
        output.puts(message) # Log the message
        redraw_indent # Redraw the spinner frame
      end
    end
  end
end