# frozen_string_literal: true

# lib/aia/content_extractor.rb
#
# Shared module for extracting text content from various response types.
# Handles RobotLab::RobotResult, SimpleFlow::Result, and plain strings.
# Include this module instead of defining extract_content locally.

module AIA
  module ContentExtractor
    # Extract text content from a response object.
    #
    # @param result the response (RobotResult, SimpleFlow::Result, String, etc.)
    # @return [String] the extracted text
    def extract_content(result)
      if defined?(SimpleFlow::Result) && result.is_a?(SimpleFlow::Result)
        return extract_network_content(result)
      end

      if result.respond_to?(:reply)
        result.reply
      elsif result.respond_to?(:last_text_content)
        result.last_text_content
      elsif result.respond_to?(:content)
        result.content
      else
        result.to_s
      end
    end

    # Extract content from a Network's SimpleFlow::Result.
    # Each robot's result is stored in context under its task name.
    # Includes per-robot timing when available.
    #
    # @param flow_result [SimpleFlow::Result]
    # @return [String]
    def extract_network_content(flow_result)
      parts = []
      flow_result.context.each do |task_name, robot_result|
        next if task_name == :run_params

        content = if robot_result.respond_to?(:reply)
                    robot_result.reply
                  elsif robot_result.respond_to?(:content)
                    robot_result.content
                  else
                    robot_result.to_s
                  end
        next unless content && !content.empty?

        duration = robot_result.respond_to?(:duration) ? robot_result.duration : nil
        robot_name = robot_result.respond_to?(:robot_name) ? robot_result.robot_name : nil
        label = robot_name && robot_name != task_name.to_s ? "#{robot_name} [#{task_name}]" : task_name.to_s
        header = if duration
                   "**#{label}** (#{format_duration(duration)}):"
                 else
                   "**#{label}:**"
                 end
        parts << "#{header}\n#{content}"
      end
      parts.join("\n\n")
    end

    # Store structured robot results into a network's shared memory.
    # Each robot's output is written as a hash under result_<task_name>.
    #
    # @param flow_result [SimpleFlow::Result]
    # @param network [RobotLab::Network]
    def store_results_in_memory(flow_result, network)
      return unless network.respond_to?(:memory)

      memory = network.memory
      flow_result.context.each do |task_name, robot_result|
        next if task_name == :run_params
        next unless robot_result.respond_to?(:reply)

        memory.current_writer = task_name.to_s
        memory.set(:"result_#{task_name}", {
          content:  robot_result.reply,
          model:    robot_result.respond_to?(:robot_name) ? robot_result.robot_name : nil,
          duration: robot_result.respond_to?(:duration) ? robot_result.duration : nil
        })
      end
    end

    # Present an AI result: extract content, record the turn, display,
    # write to output file, show metrics, speak, and print separator.
    # Callers pass only the keyword args they need; everything optional
    # defaults to nil / false so this works for both full ChatLoop turns
    # and simpler SpecialModeHandler dispatches.
    #
    # @param result the response object
    # @param streamed_content [String, nil] pre-streamed content (skips display_ai_response)
    # @param prompt [String, nil] user prompt for tracker
    # @param elapsed [Float, nil] elapsed seconds
    # @param ui_presenter [UIPresenter] for display calls
    # @param tracker [SessionTracker, nil] to record the turn
    # @param decisions [Decisions, nil] KBS decisions for tracker
    # @return [String] the extracted content
    def present_result(result, streamed_content: nil, prompt: nil, elapsed: nil,
                       ui_presenter:, tracker: nil, decisions: nil)
      content = streamed_content || extract_content(result)

      if tracker && prompt
        tracker.record_turn(
          model: AIA.config.models.first.name,
          input: prompt,
          result: result,
          decisions: decisions,
          elapsed: elapsed
        )
      end

      if streamed_content
        puts
      else
        ui_presenter.display_ai_response(content)
      end

      output_to_file(content)
      display_metrics(result, elapsed: elapsed) if respond_to?(:display_metrics, true)
      speak(content) if respond_to?(:speak, true)
      ui_presenter.display_separator

      content
    end

    # Write AI response content to the configured output file.
    #
    # @param content [String] the AI response text
    def output_to_file(content)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, 'a') { |f| f.puts "\nAI: #{content}" }
    end

    # Format a duration in seconds to a human-readable string.
    #
    # @param seconds [Float, nil]
    # @return [String]
    def format_duration(seconds)
      return "0.0s" unless seconds

      if seconds < 60
        "%.1fs" % seconds
      else
        minutes = (seconds / 60).to_i
        secs = seconds % 60
        "#{minutes}m %04.1fs" % secs
      end
    end
  end
end
