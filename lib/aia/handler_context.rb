# frozen_string_literal: true

# lib/aia/handler_context.rb
#
# Value object passed to every handler's handle(context) method.
# All fields are optional (default nil) — each handler reads only what it needs.

module AIA
  HandlerContext = Struct.new(
    :robot,           # RobotLab::Robot or Network for the current turn
    :prompt,          # String — the user prompt
    :config,          # AIA config object
    :specialist_type, # String or nil — explicit specialist role for SpawnHandler
    keyword_init: true
  )
end
