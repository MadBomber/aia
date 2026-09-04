# frozen_string_literal: true

# lib/aia/streaming_runner.rb
#
# Encapsulates the streaming execution pattern used across ChatLoop,
# MentionRouter, and expert routing. Manages spinner lifecycle and
# streaming callback for any robot.

require "tty-spinner"

module AIA
  class StreamingRunner
    # Hard ceiling on tools sent to the provider. OpenAI and Anthropic both
    # reject tool arrays longer than 128. Overridable via config.max_tools.
    DEFAULT_MAX_TOOLS = 128

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
    # :reek:TooManyStatements -- one streaming turn: spinner lifecycle, chunk-filter closure, robot run with cleanup, timing
    # :reek:DuplicateMethodCall -- @spinner.stop guards three distinct control paths (first chunk, exception, completion)
    def run(robot, prompt, header: "\nAI:\n   ", spinner_message: "Processing...", tools: nil)
      @spinner.reset
      @spinner.update(title: spinner_message)
      @spinner.auto_spin
      streamed = []
      header_printed = false
      in_think_block = false  # tracks position inside a <think>...</think> span across chunks
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      streaming_block = proc do |chunk|
        text = chunk.respond_to?(:content) ? chunk.content.to_s : chunk.to_s
        next if text.empty?

        # qwen3 and similar local reasoning models embed thinking inline in the
        # content stream wrapped in <think>...</think> tags. Filter them out
        # unless --thinking is on. Tag boundaries may split across chunks, so
        # in_think_block persists across calls via the closure.
        unless show_thinking?
          text, in_think_block = filter_thinking(text, in_think_block)
          next if text.empty?
        end

        unless header_printed
          @spinner.stop
          print header
          header_printed = true
        end

        streamed << text
        $stdout.print(text)
      end

      tools_param = resolve_tools_param(tools, robot)

      begin
        result = robot.run(prompt, mcp: :inherit, tools: tools_param, &streaming_block)
      rescue Exception # rubocop:disable Lint/RescueException
        @spinner.stop unless header_printed
        raise
      end

      @spinner.stop unless header_printed
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      content = streamed.empty? ? nil : streamed.join
      [result, content, elapsed]
    end

    private

    # Translate the resolved tool list into robot_lab's ToolConfig vocabulary,
    # then clamp it to the provider's limit:
    #   nil   -> :inherit  (no filter active / filter errored — use the full set)
    #   []    -> :none     (filter ran and found nothing relevant — send no tools)
    #   names -> names     (filtered subset; ToolConfig.filter_tools applies them)
    # Distinguishing [] from nil is what lets a "nothing relevant" turn send zero
    # tools instead of the whole build-time set.
    def resolve_tools_param(tools, robot)
      param =
        if tools.nil?
          :inherit
        elsif tools.empty?
          :none
        else
          tools
        end

      enforce_tool_cap(param, robot)
    end

    # Clamp the effective tool list to the provider's maximum. Returns the
    # value unchanged when it's already within budget (including :none, and
    # :inherit when the robot's own tool count is under the cap). When over,
    # expands :inherit to the robot's tool names, trims to the cap, and warns —
    # a reduced tool set beats a failed turn.
    def enforce_tool_cap(tools_param, robot)
      return tools_param if tools_param == :none

      max   = max_tools
      names = tools_param == :inherit ? robot_tool_names(robot) : tools_param
      size  = names.size
      return tools_param if size <= max

      dropped = size - max
      $stderr.puts(
        "⚠ Tool list (#{size}) exceeds the provider limit of #{max}; " \
        "sending #{max}, dropping #{dropped}. Enable --auto-tool-filter or reduce " \
        "the available tools to control which ones are sent."
      )
      names.first(max)
    end

    # The provider tool cap, from config.max_tools when set, else the default.
    def max_tools
      configured = AIA.respond_to?(:config) && AIA.config.respond_to?(:max_tools) ? AIA.config.max_tools : nil
      configured&.positive? ? configured : DEFAULT_MAX_TOOLS
    end

    # The robot's full set of tool names (local + MCP). Used only to size and
    # trim an over-limit :inherit set.
    def robot_tool_names(robot)
      local = robot.respond_to?(:local_tools) ? Array(robot.local_tools) : []
      mcp   = robot.respond_to?(:mcp_tools)   ? Array(robot.mcp_tools)   : []
      (local + mcp).map { |t| t.respond_to?(:name) ? t.name : t.class.name }
    end

    def show_thinking?
      AIA.config&.flags&.thinking
    end

    # Strip <think>...</think> spans from a streaming chunk, handling the case
    # where tag boundaries fall between chunk deliveries.
    #
    # @param text [String] raw chunk text
    # @param in_think_block [Boolean] whether a <think> tag is currently open
    # @return [Array(String, Boolean)] [filtered_text, updated_in_think_block]
    def filter_thinking(text, in_think_block)
      output = +''

      until text.empty?
        if in_think_block
          if (idx = text.index('</think>'))
            in_think_block = false
            text = text[(idx + '</think>'.length)..]
          else
            break  # entire remaining chunk is thinking — discard
          end
        elsif (idx = text.index('<think>'))
          output << text[0...idx]
          in_think_block = true
          text = text[(idx + '<think>'.length)..]
        else
          output << text
          break
        end
      end

      [output, in_think_block]
    end
  end
end
