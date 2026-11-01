# frozen_string_literal: true

# lib/aia/tool_approver.rb
#
# Settles what robot_lab pauses a run for: tool calls that require approval
# (an MCP server's `requires_approval:`, or a RubyLLM::Tool that declares
# it) and MCP input requests (elicitation: a server asking the user for
# values, or to visit a URL).
#
# The mode comes from `tools.approval` (CLI: --tool-approval, env:
# AIA_TOOLS__APPROVAL):
#
#   ask     -- prompt on the terminal; deny when there is no terminal (default)
#   approve -- allow every tool call that requires approval
#   deny    -- refuse them all and decline every input request
#
# Prompts go to $stderr so they never mix with the AI's answer on $stdout,
# and the turn's spinner is paused while one is shown.

module AIA
  class ToolApprover
    MODES        = %w[ask approve deny].freeze
    DEFAULT_MODE = 'ask'
    YES          = %w[y yes].freeze

    # One prompt at a time: robots in a parallel network run on their own threads.
    PROMPT_LOCK = Mutex.new

    class << self
      # The spinner of the turn in progress (set by StreamingRunner), paused
      # while a prompt is on screen.
      attr_accessor :spinner

      # The approval settings for RobotLab.build / RobotLab::RunConfig.
      #
      # @param config [AIA::Config]
      # @return [Hash] tool_approval:, plus on_tool_approval: / on_input_request: when they apply
      def options(config)
        new(mode: mode_for(config)).options
      end

      # @param config [AIA::Config]
      # @return [String] one of MODES
      def mode_for(config)
        tools = config.tools if config.respond_to?(:tools)
        mode  = (tools.approval if tools.respond_to?(:approval)).to_s.strip.downcase
        mode  = DEFAULT_MODE if mode.empty?
        return mode if MODES.include?(mode)

        AIA.debug_warn("Unknown tools.approval '#{mode}' (expected #{MODES.join(', ')}); using '#{DEFAULT_MODE}'")
        DEFAULT_MODE
      end
    end

    attr_reader :mode

    # @param mode [String] one of MODES
    # @param input [IO] where answers are read from
    # @param output [IO] where prompts are written
    # @param interactive [Boolean, nil] whether a person can answer; defaults to input.tty?
    def initialize(mode: DEFAULT_MODE, input: $stdin, output: $stderr, interactive: nil)
      @mode        = mode.to_s
      @input       = input
      @output      = output
      @interactive = interactive
    end

    # @return [Hash] the robot_lab settings for this mode
    def options
      case mode
      when 'approve' then { tool_approval: :approve, on_input_request: method(:answer_input) }
      when 'deny'    then { tool_approval: :deny }
      else { tool_approval: :deny, on_tool_approval: method(:approve?), on_input_request: method(:answer_input) }
      end
    end

    # Ask whether a tool call that requires approval may run.
    #
    # @param tool_call [RubyLLM::ToolCall]
    # @return [Boolean]
    def approve?(tool_call)
      return refuse("tool '#{tool_call.name}' requires approval and there is no terminal to ask") unless interactive?

      prompting do
        @output.puts "\nTool '#{tool_call.name}' requires approval."
        @output.puts "  arguments: #{format_arguments(tool_call.arguments)}"
        YES.include?(ask('  Allow it? [y/N] ').downcase)
      end
    end

    # Answer an MCP server's request for input.
    #
    # @param request [RubyLLM::MCP::InputRequest]
    # @return [Hash, true, nil] field values, true to accept a URL request, nil to decline
    def answer_input(request)
      return refuse("an MCP server asked for input (#{request.message}) and there is no terminal to ask") unless interactive?

      prompting do
        @output.puts "\nAn MCP server needs your input: #{request.message}"
        request.url? ? answer_url(request) : answer_form(request)
      end
    end

    private

    def interactive?
      @interactive.nil? ? @input.respond_to?(:tty?) && @input.tty? : @interactive
    end

    def refuse(reason)
      AIA.logger&.warn("Tool approval: #{reason}; refusing")
      @output.puts "[AIA] Refused: #{reason}. Set tools.approval (--tool-approval) to approve or deny."
      nil
    end

    # Pause the spinner and hold the prompt lock while a question is on screen.
    def prompting
      PROMPT_LOCK.synchronize do
        spinner = self.class.spinner
        was_spinning = spinner&.spinning?
        spinner&.pause if was_spinning
        begin
          yield
        ensure
          spinner&.resume if was_spinning
        end
      end
    end

    def ask(question)
      @output.print question
      @output.flush if @output.respond_to?(:flush)
      @input.gets.to_s.strip
    end

    def answer_url(request)
      @output.puts "  Open this page: #{request.url}"
      true if YES.include?(ask('  Continue once you have visited it? [y/N] ').downcase)
    end

    # Each field is asked in turn. A blank answer keeps the server's default;
    # a blank answer to a required field without one declines the request.
    def answer_form(request)
      request.fields.each_with_object({}) do |field, values|
        value = ask_field(field)
        return nil if value == :decline

        values[field.name] = value unless value.nil?
      end
    end

    # @return [Object, nil, :decline] the typed value, nil to keep the default, :decline to give up
    def ask_field(field)
      loop do
        raw = ask(field_question(field))
        return blank_answer(field) if raw.empty?

        value = cast(raw, field)
        return value unless value.nil?

        @output.puts "  '#{raw}' is not a valid #{field.choices ? "choice (#{field.choices.join(', ')})" : field.type}."
      end
    end

    def blank_answer(field)
      field.required? && field.default.nil? ? :decline : nil
    end

    def field_question(field)
      label = field.title || field.name.to_s
      parts = ["  #{label}"]
      parts << "(#{field.description})" if field.description
      parts << "[#{field.choices.join('/')}]" if field.choices
      parts << "default: #{field.default}" unless field.default.nil?
      parts << '*' if field.required?
      "#{parts.join(' ')}: "
    end

    # @return [Object, nil] nil when +raw+ does not fit the field
    def cast(raw, field)
      return (field.choices.map(&:to_s).include?(raw) ? field.choices.find { it.to_s == raw } : nil) if field.choices

      case field.type
      when 'integer' then Integer(raw, exception: false)
      when 'number'  then Float(raw, exception: false)
      when 'boolean' then boolean(raw)
      else raw
      end
    end

    def boolean(raw)
      return true  if %w[y yes true 1].include?(raw.downcase)
      return false if %w[n no false 0].include?(raw.downcase)

      nil
    end

    def format_arguments(arguments)
      text = arguments.to_h.map { |key, value| "#{key}=#{value.inspect}" }.join(', ')
      text = '(none)' if text.empty?
      text.length > 300 ? "#{text[0, 300]}..." : text
    end
  end
end
