# frozen_string_literal: true

# lib/aia/debate_handler.rb
#
# Multi-round debate between robots in a network.
# Each robot responds to the previous round's outputs until
# convergence is reached or a round limit is hit.
# Uses TypedBus for bus attachment and SharedMemory for state.
# Uses Async::Barrier for concurrent robot execution per round.

require 'async'

module AIA
  class DebateHandler
    include ContentExtractor
    include HandlerProtocol

    MAX_ROUNDS           = 5
    MIN_ROUNDS           = 2
    SIMILARITY_THRESHOLD = 0.85
    CONVERGENCE_SIGNAL   = "CONVERGED"

    # Sentinel value for a robot that failed to respond in a round.
    # Treated as empty string for convergence; rendered with [FAILED] marker.
    FailedResponse = Data.define(:robot_name, :error_message)

    def initialize(robot:, ui_presenter:, tracker:)
      @robot        = robot
      @ui_presenter = ui_presenter
      @tracker      = tracker
    end

    attr_writer :robot

    # Run a debate between robots in the network.
    #
    # @param context [HandlerContext] — reads context.prompt
    # @return [String, nil] formatted debate results, or nil if not applicable
    def handle(context)
      prompt = context.prompt
      return nil unless @robot.is_a?(RobotLab::Network)

      robots = @robot.robots.values
      return nil if robots.size < 2

      # Ensure all robots share a bus
      bus = TypedBus::MessageBus.new
      robots.each { |r| r.with_bus(bus) }

      @ui_presenter.display_info(
        "Debate between #{robots.map(&:name).join(', ')}..."
      )

      rounds = []

      MAX_ROUNDS.times do |round|
        round_context = build_round_context(prompt, rounds)

        round_results = Sync do
          barrier = Async::Barrier.new
          tasks = robots.map do |robot|
            barrier.async do
              @ui_presenter.display_info("  Round #{round + 1}: #{robot.name}...")
              result  = robot.run(round_context, mcp: :inherit, tools: :inherit)
              content = extract_content(result)
              write_to_memory(round, robot.name, content)
              { robot: robot.name, content: content }
            rescue => e
              FailedResponse.new(robot_name: robot.name, error_message: e.message)
            end
          end
          barrier.wait
          tasks.map(&:wait)
        end

        raise DebateError, "All robots failed in round #{round + 1}" if
          round_results.all? { |r| r.is_a?(FailedResponse) }

        previous = rounds.last
        rounds << round_results

        if converged?(round, round_results, previous)
          @ui_presenter.display_info("  Converged in round #{round + 1}.")
          break
        end
      end

      @tracker.record_turn(
        model: AIA.config.models.first.name,
        input: prompt,
        result: rounds
      )

      format_rounds(rounds)
    end

    private

    def build_round_context(prompt, rounds)
      return prompt if rounds.empty?

      previous = rounds.last.map { |r|
        if r.is_a?(FailedResponse)
          "#{r.robot_name}: [FAILED: #{r.error_message}]"
        else
          "#{r[:robot]}: #{r[:content]}"
        end
      }.join("\n\n")

      <<~CONTEXT
        Topic: #{prompt}

        Previous round:
        #{previous}

        Respond to the points above. Say CONVERGED if you agree with the overall consensus and provide a final summary. Otherwise refine your position.
      CONTEXT
    end

    def converged?(round_index, current_results, previous_results)
      return false if round_index < MIN_ROUNDS - 1

      # Fast path: every robot explicitly signaled convergence.
      return true if all_signaled_convergence?(current_results)

      return false if previous_results.nil?

      current_text  = current_results.map  { |r| r.is_a?(FailedResponse) ? "" : r[:content].to_s }.join(" ")
      previous_text = previous_results.map { |r| r.is_a?(FailedResponse) ? "" : r[:content].to_s }.join(" ")

      scores = SimilarityScorer.score([previous_text, current_text])
      (scores[1] || 0.0) >= SIMILARITY_THRESHOLD
    end

    def all_signaled_convergence?(round_results)
      round_results.all? do |r|
        next false if r.is_a?(FailedResponse)
        r[:content].to_s.upcase.include?(CONVERGENCE_SIGNAL)
      end
    end

    def write_to_memory(round, robot_name, content)
      return unless @robot.respond_to?(:memory)

      @robot.memory.current_writer = robot_name
      @robot.memory.set(:"debate_r#{round}_#{robot_name}", content)
    end

    def format_rounds(rounds)
      lines = []
      rounds.each_with_index do |round, i|
        lines << "### Round #{i + 1}"
        round.each do |entry|
          if entry.is_a?(FailedResponse)
            lines << "**#{entry.robot_name}**: [FAILED] #{entry.error_message}\n"
          else
            lines << "**#{entry[:robot]}**: #{entry[:content]}\n"
          end
        end
      end
      lines.join("\n")
    end
  end
end
