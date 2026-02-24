# frozen_string_literal: true

# lib/aia/chat_loop.rb
#
# Thin interactive chat shell for AIA v2.
# Delegates to StreamingRunner, MentionRouter, and SpecialModeHandler
# for execution concerns. Owns the REPL loop, directive processing,
# expert routing, and output coordination.

require "reline"
require "pm"

module AIA
  class ChatLoop
    include ContentExtractor

    def initialize(robot, ui_presenter, directive_processor, rule_router,
                   session_tracker: nil, alias_registry: nil)
      @robot               = robot
      @ui_presenter        = ui_presenter
      @directive_processor = directive_processor
      @rule_router         = rule_router
      @tracker             = session_tracker || SessionTracker.new
      @alias_registry      = alias_registry || ModelAliasRegistry.new
      @model_switch_handler = ModelSwitchHandler.new(@alias_registry, @ui_presenter)

      @streaming_runner = StreamingRunner.new
      @mention_router = MentionRouter.new(
        ui_presenter: @ui_presenter,
        tracker: @tracker,
        streaming_runner: @streaming_runner
      )
      @special_mode_handler = SpecialModeHandler.new(
        robot: @robot,
        ui_presenter: @ui_presenter,
        tracker: @tracker,
        rule_router: @rule_router
      )
    end

    # Start the interactive chat session
    def start(skip_context_files: false)
      setup_session
      process_initial_context(skip_context_files)
      run_loop
    ensure
      @ui_presenter.display_chat_end
    end

    private

    def setup_session
      puts "\nEntering interactive chat mode..."
      @ui_presenter.display_chat_header
      Signal.trap("INT") { exit }
      Reline::HISTORY.clear
    end

    def process_initial_context(skip_context_files)
      return if skip_context_files || !AIA.config.context_files || AIA.config.context_files.empty?

      context = AIA.config.context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return if context.empty?

      result, streamed_content, _elapsed = @streaming_runner.run(@robot, context)
      content = streamed_content || extract_content(result)

      if streamed_content
        puts
      else
        @ui_presenter.display_ai_response(content)
      end
      output_to_file(content)
      speak(content)
      @ui_presenter.display_separator
    end

    def run_loop
      loop do
        follow_up_prompt = @ui_presenter.ask_question

        break if follow_up_prompt.nil? || follow_up_prompt.strip.downcase == "exit" || follow_up_prompt.strip.empty?

        log_user_input(follow_up_prompt)

        if follow_up_prompt.strip.start_with?('/')
          if @directive_processor.directive?(follow_up_prompt)
            follow_up_prompt = process_directive(follow_up_prompt)
            next if follow_up_prompt.nil?
          else
            name = follow_up_prompt.strip.split(' ').first
            @ui_presenter.display_info("Unknown directive: #{name}  (use /help to see available directives)")
            next
          end
        end

        begin
          processed_prompt = PM.parse_string(follow_up_prompt).to_s
        rescue StandardError => e
          @ui_presenter.display_info("Error: #{e.class}: #{e.message}")
          next
        end

        # Rules may modify config before each turn
        decisions = @rule_router.evaluate_turn(AIA.config, processed_prompt)

        # Check for model switch intent
        if @model_switch_handler.handle(decisions, AIA.config)
          update_robot
          next
        end

        # Check for special execution modes (/verify, /decompose, /concurrent)
        if @special_mode_handler.handle(processed_prompt)
          next
        end

        # Expert routing (per-turn specialist)
        if AIA.config.flags.expert_routing
          if route_to_expert(decisions, processed_prompt)
            next
          end
        end

        # @mention routing — send to specific robot(s) in the network
        if @mention_router.handle(@robot, processed_prompt)
          next
        end

        # Standard execution with streaming
        begin
          result, streamed_content, _elapsed = @streaming_runner.run(@robot, processed_prompt)
        rescue StandardError => e
          @ui_presenter.display_info("Error communicating with AI: #{e.class}: #{e.message}")
          next
        end

        content = streamed_content || extract_content(result)

        @tracker.record_turn(
          model: AIA.config.models.first.name,
          input: processed_prompt,
          result: result,
          decisions: decisions
        )

        @rule_router.evaluate_response(AIA.config, { accepted: true, model: AIA.config.models.first.name })

        if streamed_content
          puts
        else
          @ui_presenter.display_ai_response(content)
        end
        output_to_file(content)
        display_metrics(result)
        speak(content)
        @ui_presenter.display_separator
      end
    end

    # Update robot reference after a model switch and propagate to sub-components
    def update_robot
      @robot = AIA.client
      @special_mode_handler.robot = @robot
    end

    def route_to_expert(decisions, prompt)
      router = ExpertRouter.new(decisions)
      specialist = router.route(AIA.config)
      return false unless specialist

      @ui_presenter.display_info("Routing to specialist: #{specialist.respond_to?(:name) ? specialist.name : 'expert'}")

      result, streamed_content, _elapsed = @streaming_runner.run(
        specialist, prompt,
        header: "\nAI (Expert):\n   ",
        spinner_message: "Expert processing..."
      )

      content = streamed_content || extract_content(result)
      @tracker.record_turn(model: AIA.config.models.first.name, input: prompt, result: result)

      if streamed_content
        puts
      else
        @ui_presenter.display_ai_response(content)
      end
      output_to_file(content)
      display_metrics(result)
      speak(content)
      @ui_presenter.display_separator
      true
    rescue StandardError => e
      @ui_presenter.display_info("Expert routing failed: #{e.message}")
      false
    end

    def process_directive(follow_up_prompt)
      directive_output = @directive_processor.process(follow_up_prompt, nil)

      if follow_up_prompt.strip.start_with?("/clear", "/checkpoint", "/restore", "/review", "/context")
        @ui_presenter.display_info(directive_output) unless directive_output.nil? || directive_output.strip.empty?
        return nil
      end

      return nil if directive_output.nil? || directive_output.strip.empty?

      puts "\n#{directive_output}\n"
      "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
    end

    # Display token metrics if enabled
    def display_metrics(result)
      return unless AIA.config.flags.tokens

      if result.respond_to?(:output) && result.output.any?
        last_msg = result.output.last
        if last_msg.respond_to?(:input_tokens)
          metrics = {
            model_id: result.respond_to?(:robot_name) ? result.robot_name : "unknown",
            input_tokens: last_msg.input_tokens,
            output_tokens: last_msg.output_tokens
          }
          @ui_presenter.display_token_metrics(metrics)
        end
      end
    end

    def output_to_file(content)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, 'a') { |f| f.puts "\nAI: #{content}" }
    end

    def log_user_input(input)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, "a") { |f| f.puts "\nYou: #{input}" }
    end

    def speak(content)
      return unless AIA.speak?

      command = AIA.config.audio.speak_command || 'say'
      system(command, content.to_s)
    rescue StandardError => e
      warn "Warning: Speech failed: #{e.message}"
    end
  end
end
