# frozen_string_literal: true

# lib/aia/llm_error_collector.rb
#
# A robot_lab hook that remembers the exceptions robots raise while a
# pipeline step runs. robot_lab's Network shields a robot's exception into
# an "Error: ..." reply so one failing robot cannot crash the network, which
# also hides the failure from aia: a batch run would print the error as the
# answer and exit 0. The on_error hook fires before the shield, so the
# PipelineOrchestrator can ask afterwards whether the step really failed.

module AIA
  class LLMErrorCollector < RobotLab::Hook
    Entry = Data.define(:robot_name, :error) do
      def to_s
        prefix = robot_name.empty? ? '' : "#{robot_name}: "
        "#{prefix}#{error.class}: #{error.message}"
      end
    end

    @errors = []
    @mutex  = Mutex.new

    class << self
      # Register the collector on +registry+ once. robot_lab's global
      # registry (the default) is consulted by every Robot#run, including
      # the robots a Network runs in parallel threads.
      #
      # @param registry [RobotLab::HookRegistry]
      def install!(registry = RobotLab.hooks)
        return if registry.registrations.any? { |reg| reg.handler_class == self }

        registry.on(self)
      end

      # robot_lab hook: a robot run raised +ctx.error+.
      #
      # @param ctx [RobotLab::RunHookContext]
      def on_error(ctx)
        robot_name = ctx.respond_to?(:robot) ? ctx.robot&.name.to_s : ''
        @mutex.synchronize { @errors << Entry.new(robot_name: robot_name, error: ctx.error) }
      end

      # Forget the errors of the previous step.
      def reset!
        @mutex.synchronize { @errors.clear }
      end

      # @return [Array<Entry>] the errors recorded since the last reset!
      def errors
        @mutex.synchronize { @errors.dup }
      end

      def errors?
        !errors.empty?
      end

      # One line naming the prompt and every distinct error it hit.
      #
      # @param prompt_id [String]
      # @return [String]
      def message(prompt_id)
        "LLM error in prompt '#{prompt_id}': #{errors.map(&:to_s).uniq.join('; ')}"
      end
    end
  end
end
