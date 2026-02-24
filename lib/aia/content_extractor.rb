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
