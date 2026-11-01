# frozen_string_literal: true

# lib/aia/history_transfer.rb
#
# Stateless module for transferring conversation history between robots.
# Extracted from RobotFactory to isolate the history transfer concern.
#
# Both arguments may be a single RobotLab::Robot or a RobotLab::Network (the
# interactive session always runs a crew). History is read from the old
# runnable's chief — the robot the user has been talking to — and carried to
# every member of the new crew.

module AIA
  module HistoryTransfer
    MODES        = %i[clean replay summarize].freeze
    DEFAULT_MODE = :summarize

    module_function

    # The history mode configured for model switches (config.model_switch_history),
    # falling back to DEFAULT_MODE when it is unset or not a known mode.
    #
    # @param config [AIA::Config, nil]
    # @return [Symbol] one of MODES
    def mode_for(config)
      value = config.respond_to?(:model_switch_history) ? config.model_switch_history : nil
      mode  = value.to_s.strip.downcase.to_sym
      MODES.include?(mode) ? mode : DEFAULT_MODE
    end

    # The user/assistant turns of +runnable+'s chief, oldest first. System
    # prompts and tool traffic are left out: they belong to the old robot.
    #
    # @param runnable [RobotLab::Robot, RobotLab::Network, nil]
    # @return [Array<RubyLLM::Message>]
    def conversation(runnable)
      chief = chief_of(runnable)
      return [] unless chief.respond_to?(:messages)

      Array(chief.messages).select do |msg|
        msg.respond_to?(:role) && %i[user assistant].include?(msg.role) && !msg.content.to_s.strip.empty?
      end
    end

    # The robot whose conversation the user sees: a network's chief, or the robot itself.
    def chief_of(runnable)
      runnable.respond_to?(:chief) ? runnable.chief : runnable
    end

    # The robots that should receive the transferred history.
    #
    # @param runnable [RobotLab::Robot, RobotLab::Network]
    # @return [Array<RobotLab::Robot>]
    def recipients(runnable)
      runnable.respond_to?(:crew) ? Array(runnable.crew) : [runnable]
    end

    # Replay conversation history from an old robot to a new one.
    #
    # Performance: O(N) API calls per recipient, where N = number of user
    # messages. Each user message triggers a full LLM round-trip on the new
    # model. MCP/tools are disabled during replay to avoid side effects.
    def replay_history(old_robot, new_robot)
      user_turns = conversation(old_robot).select { it.role == :user }
      return if user_turns.empty?

      recipients(new_robot).each do |robot|
        user_turns.each { robot.run(it.content.to_s, mcp: :none, tools: :none) }
      end
    rescue StandardError => e
      $stderr.puts "Warning: History replay failed: #{e.message}"
    end

    # Summarize conversation history and inject into new robot.
    #
    # Performance: one summary call on the old model, plus one injection call
    # per recipient, regardless of conversation length. Faster than :replay
    # for conversations with >2 turns, but loses per-turn context fidelity.
    def summarize_history(old_robot, new_robot)
      turns = conversation(old_robot)
      return if turns.empty?

      transcript = turns.map { "#{it.role}: #{it.content}" }.join("\n")
      summary    = chief_of(old_robot).run("Summarize this conversation concisely for context transfer:\n#{transcript}",
                                           mcp: :none, tools: :none)
      content = summary.respond_to?(:reply) ? summary.reply : summary.to_s

      recipients(new_robot).each do |robot|
        robot.run("Context from previous conversation: #{content}", mcp: :none, tools: :none)
      end
    rescue StandardError => e
      $stderr.puts "Warning: History summarization failed: #{e.message}"
    end
  end
end
