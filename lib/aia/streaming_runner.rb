# frozen_string_literal: true

# lib/aia/streaming_runner.rb
#
# Encapsulates the streaming execution pattern used across ChatLoop,
# MentionRouter, and expert routing. Manages spinner lifecycle and
# streaming callback for any robot.

require "tty-spinner"

module AIA
  class StreamingRunner
    def initialize
      @spinner = TTY::Spinner.new("[:spinner] Processing...", format: :bouncing_ball)
    end

    # Run a robot with streaming output.
    # Spinner shows until the first chunk arrives, then stops and
    # chunks are printed directly to stdout.
    #
    # @param robot [RobotLab::Robot, RobotLab::Network] the robot to run
    # @param prompt [String] the prompt to send
    # @param header [String] text printed before the first streamed chunk
    # @param spinner_message [String] spinner label
    # @param tools [Array<String>, nil] tool names to allow for this turn (nil = all)
    # @return [Array(Object, String, Float)] [result, streamed_content_or_nil, elapsed_seconds]
    def run(robot, prompt, header: "\nAI:\n   ", spinner_message: "Processing...", tools: nil)
      @spinner.reset
      @spinner.update(title: spinner_message)
      @spinner.auto_spin
      streamed = []
      header_printed = false
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      streaming_block = proc do |chunk|
        text = chunk.respond_to?(:content) ? chunk.content.to_s : chunk.to_s
        next if text.empty?

        unless header_printed
          @spinner.stop
          print header
          header_printed = true
        end

        streamed << text
        $stdout.print(text)
      end

      # When a filtered tool list is provided, pass those names to
      # robot.run so robot_lab's ToolConfig.filter_tools applies them.
      # Otherwise inherit the full build-time tool set.
      tools_param = tools && !tools.empty? ? tools : :inherit

      begin
        result = if robot.is_a?(RobotLab::Network)
                   robot.run(message: prompt)
                 else
                   robot.run(prompt, mcp: :inherit, tools: tools_param, &streaming_block)
                 end
      rescue Exception
        @spinner.stop unless header_printed
        raise
      end

      @spinner.stop unless header_printed
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      content = streamed.empty? ? nil : streamed.join
      [result, content, elapsed]
    end
  end
end
