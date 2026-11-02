# frozen_string_literal: true

# lib/aia/handler_protocol.rb
#
# Uniform interface for all turn-level handlers.
# Include this module and implement handle(context) where context
# is an AIA::HandlerContext value object.

module AIA
  module HandlerProtocol
    # Process a turn. Each handler reads only the context fields it needs.
    #
    # @param context [AIA::HandlerContext]
    # @return handler-specific result (String content, Boolean, or nil)
    def handle(context)
      raise NotImplementedError, "#{self.class} must implement #handle(context)"
    end
  end
end
