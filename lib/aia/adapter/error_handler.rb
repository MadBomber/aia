# lib/aia/adapter/error_handler.rb
# frozen_string_literal: true

module AIA
  module Adapter
    module ErrorHandler
      # Handles tool execution crashes gracefully
      # Logs error with short traceback, repairs conversation, and returns error message
      def handle_tool_crash(chat_instance, exception)
        error_msg = "Tool error: #{exception.class} - #{exception.message}"

        # Log error with short traceback (first 5 lines)
        warn "\n  #{error_msg}"
        if exception.backtrace
          short_trace = exception.backtrace.first(5).map { |line| "   #{line}" }.join("\n")
          warn short_trace
        end
        warn "" # blank line for readability

        # Repair incomplete tool calls to maintain conversation integrity
        repair_incomplete_tool_calls(chat_instance, error_msg)

        # Return error message so conversation can continue
        error_msg
      end

      # Repairs conversation history when a tool call fails (timeout, error, etc.)
      # When an MCP tool times out, the conversation gets into an invalid state:
      # - Assistant message with tool_calls was added to history
      # - But no tool result message was added (because the tool failed)
      # - The API requires tool results for each tool_call_id
      # This method adds synthetic error tool results to fix the conversation.
      def repair_incomplete_tool_calls(chat_instance, error_message)
        return unless chat_instance.respond_to?(:messages)

        messages = chat_instance.messages
        return if messages.empty?

        # Find the last assistant message that has tool_calls
        last_assistant_with_tools = messages.reverse.find do |msg|
          msg.role == :assistant && msg.respond_to?(:tool_calls) && msg.tool_calls&.any?
        end

        return unless last_assistant_with_tools

        # Get the tool_call_ids that need results
        tool_call_ids = last_assistant_with_tools.tool_calls.keys

        # Check which tool_call_ids already have results
        existing_tool_results = messages.select { |m| m.role == :tool }.map(&:tool_call_id).compact

        # Add synthetic error results for any missing tool_call_ids
        tool_call_ids.each do |tool_call_id|
          next if existing_tool_results.include?(tool_call_id.to_s) || existing_tool_results.include?(tool_call_id)

          # Add a synthetic tool result with the error message
          chat_instance.add_message(
            role: :tool,
            content: "Error: #{error_message}",
            tool_call_id: tool_call_id
          )
        end
      rescue StandardError
        # Don't let repair failures cascade
      end
    end
  end
end
