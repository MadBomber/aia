# frozen_string_literal: true

# lib/aia/tools/delegate_to_foreman_tool.rb
#
# Lightweight tool given to Tobor (and other primary robots) that
# delegates task board operations to Foreman, a specialist robot
# with full TaskBoardTool access. Foreman is built on first use
# and cached for the session.

module AIA
  class DelegateToForemanTool < RubyLLM::Tool
    description "Delegate a task management request to Foreman, the task board manager. " \
                "Use this when you need to create, assign, track, or manage tasks. " \
                "Pass a natural language description of what you need done on the task board."

    param :request, type: :string, required: true,
          desc: "Natural language description of the task board operation " \
                "(e.g., 'create a research task about recessions assigned to Tobor with labels research, economics')"

    def available?
      AIA.task_coordinator&.available? || false
    end

    def execute(request:, **_params)
      foreman = self.class.foreman
      result = foreman.run(request)
      result.respond_to?(:reply) ? result.reply : result.to_s
    rescue StandardError => e
      "Foreman error: #{e.message}"
    end

    class << self
      def foreman
        @foreman ||= build_foreman
      end

      def reset!
        @foreman = nil
      end

      private

      def build_foreman
        model_spec = AIA.config.models.first
        run_config = RobotFactory.build_run_config(AIA.config)

        build_opts = {
          name:          'Foreman',
          model:         model_spec.name,
          system_prompt: foreman_system_prompt,
          local_tools:   [TaskBoardTool],
          config:        run_config
        }
        build_opts[:provider] = RobotFactory.resolve_provider(model_spec) if model_spec.provider

        RobotLab.build(**build_opts)
      end

      def foreman_system_prompt
        <<~PROMPT
          You are Foreman, the task board manager. You manage a shared TrakFlow
          task board where robots can create, claim, and complete tasks.

          When given a request, use the task_board tool to execute it. Be precise
          and efficient — execute the operation and report the result concisely.

          You can: create tasks, plan multi-step work, check ready tasks, claim
          tasks, mark tasks complete, block tasks, and report board status.
        PROMPT
      end
    end
  end
end
