# frozen_string_literal: true

# lib/aia/history_transfer.rb
#
# Stateless module for transferring conversation history between robots.
# Extracted from RobotFactory to isolate the history transfer concern.

module AIA
  module HistoryTransfer
    module_function

    # Replay conversation history from an old robot to a new one.
    #
    # Performance: O(N) API calls where N = number of user messages.
    # Each user message triggers a full LLM round-trip on the new model.
    # For a 10-turn conversation with a local model (~1s/turn), expect ~10s.
    # For a cloud model (~2-5s/turn), expect 20-50s. MCP/tools are disabled
    # during replay to avoid side effects.
    def replay_history(old_robot, new_robot)
      return unless old_robot.respond_to?(:messages)

      old_robot.messages.each do |msg|
        next unless msg.respond_to?(:role) && msg.role == :user
        new_robot.run(msg.content, mcp: :none, tools: :none)
      end
    rescue StandardError => e
      warn "Warning: History replay failed: #{e.message}"
    end

    # Summarize conversation history and inject into new robot.
    #
    # Performance: Exactly 2 API calls regardless of conversation length.
    # 1) Summarize on old model (input tokens proportional to conversation)
    # 2) Inject summary into new model (small fixed-size prompt)
    # Faster than :replay for conversations with >2 turns, but loses
    # per-turn context fidelity. Total latency ~4-10s for cloud models.
    def summarize_history(old_robot, new_robot)
      return unless old_robot.respond_to?(:messages) && old_robot.messages.any?

      summary_lines = old_robot.messages.map do |msg|
        "#{msg.role}: #{msg.content}" if msg.respond_to?(:role)
      end.compact

      return if summary_lines.empty?

      summary_prompt = "Summarize this conversation concisely for context transfer:\n#{summary_lines.join("\n")}"
      summary = old_robot.run(summary_prompt, mcp: :none, tools: :none)
      content = summary.respond_to?(:reply) ? summary.reply : summary.to_s

      new_robot.run("Context from previous conversation: #{content}", mcp: :none, tools: :none)
    rescue StandardError => e
      warn "Warning: History summarization failed: #{e.message}"
    end
  end
end
