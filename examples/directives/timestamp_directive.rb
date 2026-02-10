# examples/directives/timestamp_directive.rb
#
# A custom directive that inserts a formatted timestamp.
# Load with: aia --tools directives/timestamp_directive.rb
#
# In a prompt file (ERB):
#   Generated at: <%= timestamp %>
#   Generated at: <%= timestamp '%Y-%m-%d' %>
#
# In chat mode:
#   /timestamp
#   /timestamp %Y-%m-%d

module AIA
  class CustomDirectives < Directive
    desc "Insert current timestamp (optional strftime format, default: %Y-%m-%d %H:%M:%S)"
    def timestamp(args = [], context_manager = nil)
      format = args.empty? ? '%Y-%m-%d %H:%M:%S' : args.join(' ')
      Time.now.strftime(format)
    end
  end
end
