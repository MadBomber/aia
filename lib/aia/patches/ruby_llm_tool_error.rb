# lib/aia/patches/ruby_llm_tool_error.rb
#
# Patches RubyLLM::Chat#execute_tool to rescue any exception raised during
# tool execution and return it as an error hash instead of raising.
#
# Without this patch, an exception inside a tool skips the `add_message`
# call in handle_tool_calls, leaving an orphaned tool_call in the
# conversation history with no matching tool_result. Most LLMs reject
# that state on the next request, killing the session.

module RubyLLM
  class Chat
    private

    def execute_tool(tool_call)
      tool = tools[tool_call.name.to_sym]
      if tool.nil?
        return {
          error: "Model tried to call unavailable tool `#{tool_call.name}`. " \
                 "Available tools: #{tools.keys.to_json}."
        }
      end

      begin
        tool.call(tool_call.arguments)
      rescue Interrupt, SignalException, SystemExit
        raise
      rescue Exception => e
        RubyLLM.logger.warn { "Tool #{tool_call.name} raised #{e.class}: #{e.message}" }
        { error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
