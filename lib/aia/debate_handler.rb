# frozen_string_literal: true

# lib/aia/debate_handler.rb
#
# Multi-round debate between robots in a network.
# Each robot responds to the previous round's outputs until
# convergence is reached or a round limit is hit.
# Uses TypedBus for bus attachment and SharedMemory for state.

module AIA
  class DebateHandler
    include ContentExtractor
    include HandlerProtocol

    MAX_ROUNDS          = 5
    MIN_ROUNDS          = 2
    SIMILARITY_THRESHOLD = 0.85

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
        round_results = []

        robots.each do |robot|
          @ui_presenter.display_info("  Round #{round + 1}: #{robot.name}...")

          context = build_round_context(prompt, rounds)
          result = robot.run(context, mcp: :inherit, tools: :inherit)
          content = extract_content(result)

          round_results << { robot: robot.name, content: content }

          # Write to shared memory
          write_to_memory(round, robot.name, content)
        end

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
        "#{r[:robot]}: #{r[:content]}"
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
      return false if previous_results.nil?

      current_text  = current_results.map  { |r| r[:content].to_s }.join(" ")
      previous_text = previous_results.map { |r| r[:content].to_s }.join(" ")

      scores = SimilarityScorer.score([previous_text, current_text])
      (scores[1] || 0.0) >= SIMILARITY_THRESHOLD
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
          lines << "**#{entry[:robot]}**: #{entry[:content]}\n"
        end
      end
      lines.join("\n")
    end
  end
end
