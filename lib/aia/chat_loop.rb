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

    def initialize(robot, ui_presenter, directive_processor,
                   session_tracker: nil, alias_registry: nil, filters: {})
      @robot               = robot
      @ui_presenter        = ui_presenter
      @directive_processor = directive_processor
      @tracker             = session_tracker || SessionTracker.new
      @alias_registry      = alias_registry || ModelAliasRegistry.new
      @model_switch_handler = ModelSwitchHandler.new(@alias_registry, @ui_presenter)
      @filters             = filters

      @streaming_runner = StreamingRunner.new
      @mention_router = MentionRouter.new(
        ui_presenter: @ui_presenter,
        tracker: @tracker,
        streaming_runner: @streaming_runner
      )
      @special_mode_handler = SpecialModeHandler.new(
        robot: @robot,
        ui_presenter: @ui_presenter,
        tracker: @tracker
      )
      @tool_filter_strategy = ToolFilterStrategy.new(
        filters: filters,
        ui_presenter: @ui_presenter
      )
    end

    # Start the interactive chat session
    def start(skip_context_files: false)
      setup_session
      process_initial_context(skip_context_files)
      run_loop
    rescue StandardError => e
      AIA.debug_warn("ChatLoop error: #{e.class}: #{e.message}", exc: e)
    ensure
      @ui_presenter.display_chat_end
    end

    private

    def setup_session
      puts "\nEntering interactive chat mode..."
      @ui_presenter.display_chat_header
      Signal.trap("INT") { exit }
      @ui_presenter.load_chat_history
    end

    def process_initial_context(skip_context_files)
      return if skip_context_files || !AIA.config.context_files || AIA.config.context_files.empty?

      context = AIA.config.context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return if context.empty?

      result, streamed_content, _elapsed = @streaming_runner.run(@robot, context)
      present_result(result,
        streamed_content: streamed_content,
        ui_presenter: @ui_presenter
      )
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

        # Check for model switch intent (explicit user request takes priority)
        if @model_switch_handler.handle(HandlerContext.new(config: AIA.config))
          update_robot
          next
        end

        active_robot = @robot

        # Check for special execution modes (/verify, /decompose, /concurrent)
        if @special_mode_handler.handle(processed_prompt)
          clear_turn_mcp_filter
          next
        end

        # @mention routing — send to specific robot(s) in the network
        if @mention_router.handle(HandlerContext.new(robot: active_robot, prompt: processed_prompt))
          clear_turn_mcp_filter
          next
        end

        # Debug: show actual tools available to the LLM vs KBS-filtered list
        log_robot_tools(active_robot)

        # Resolve tool list via strategy (A=KBS, B=TF-IDF, or comparison)
        resolved_tools = @tool_filter_strategy.resolve(processed_prompt)
        begin
          result, streamed_content, elapsed = @streaming_runner.run(
            active_robot, processed_prompt, tools: resolved_tools
          )
        rescue StandardError => e
          @ui_presenter.display_info("Error communicating with AI: #{e.class}: #{e.message}")
          clear_turn_mcp_filter
          next
        end

        # Increment shared memory turn counter for multi-model networks
        if @robot.respond_to?(:memory) && @robot.memory.respond_to?(:data)
          data = @robot.memory.data
          count = data.respond_to?(:turn_count) ? (data.turn_count || 0) : 0
          data.turn_count = count + 1
        end

        present_result(result,
          streamed_content: streamed_content,
          prompt: processed_prompt,
          elapsed: elapsed,
          ui_presenter: @ui_presenter,
          tracker: @tracker
        )

        # Clear per-turn MCP filter for next turn
        clear_turn_mcp_filter
      end
    end

    # Clear per-turn MCP server filter so next turn sees all
    def clear_turn_mcp_filter
      AIA.turn_state.active_mcp_servers = nil
    end

    # Update robot reference after a model switch and propagate to sub-components
    def update_robot
      @robot = AIA.client
      @special_mode_handler.robot = @robot
    end

    def process_directive(follow_up_prompt)
      directive_output = @directive_processor.process(follow_up_prompt, nil)

      # These directives either mutate state or set a mode flag for the NEXT
      # prompt.  Display their confirmation and return nil so the loop skips
      # forwarding them to the robot (which would fire the handler prematurely
      # on wrapper text and consume the flag before the real prompt arrives).
      if @directive_processor.state_setting?(follow_up_prompt)
        @ui_presenter.display_info(directive_output) unless directive_output.nil? || directive_output.strip.empty?
        return nil
      end

      return nil if directive_output.nil? || directive_output.strip.empty?

      puts "\n#{directive_output}\n"
      "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
    end

    # Display token metrics if enabled.
    # Handles both single-robot results and multi-model network results.
    #
    # Token data lives on the raw RubyLLM::Message stored in
    # RobotResult#raw (RobotLab::Message objects do not carry usage info).
    def display_metrics(result, elapsed: nil)
      return unless AIA.config.flags.tokens

      if defined?(SimpleFlow::Result) && result.is_a?(SimpleFlow::Result)
        display_network_metrics(result)
        return
      end

      raw = result.respond_to?(:raw) ? result.raw : nil
      return unless raw && raw.respond_to?(:input_tokens) && raw.input_tokens

      model_id = extract_model_id(raw) || AIA.config.models.first.name
      metrics = {
        model_id:      model_id,
        input_tokens:  raw.input_tokens,
        output_tokens: raw.output_tokens,
        elapsed:       elapsed
      }
      @ui_presenter.display_token_metrics(metrics)
    end

    # Extract per-robot metrics from a network SimpleFlow::Result
    # and display the multi-model cost table.
    #
    # Each robot_result.raw holds the original RubyLLM::Message with
    # input_tokens, output_tokens, and model_id.
    # Each robot_result.duration holds the elapsed seconds.
    # Similarity scores compare each model's response text against the
    # first model using TF-IDF cosine similarity.
    def display_network_metrics(flow_result)
      metrics_list = []
      response_texts = []

      flow_result.context.each do |task_name, robot_result|
        next if task_name == :run_params
        next unless robot_result.respond_to?(:raw)

        raw = robot_result.raw
        next unless raw && raw.respond_to?(:input_tokens) && raw.input_tokens

        model_id = extract_model_id(raw)
        display_name = robot_result.respond_to?(:robot_name) ? robot_result.robot_name : task_name.to_s
        elapsed = robot_result.respond_to?(:duration) ? robot_result.duration : nil

        # Collect response text for similarity scoring
        text = if robot_result.respond_to?(:reply)
                 robot_result.reply.to_s
               elsif robot_result.respond_to?(:content)
                 robot_result.content.to_s
               else
                 ""
               end
        response_texts << text

        metrics_list << {
          model_id:      model_id || display_name,
          display_name:  display_name,
          input_tokens:  raw.input_tokens || 0,
          output_tokens: raw.output_tokens || 0,
          elapsed:       elapsed
        }
      end

      return if metrics_list.empty?

      # Compute TF-IDF similarity against the first model's response
      if metrics_list.size > 1
        scores = SimilarityScorer.score(response_texts)
        metrics_list.each_with_index { |m, i| m[:similarity] = scores[i] }
      end

      @ui_presenter.display_multi_model_metrics(metrics_list)
    end

    # Pull the actual model identifier from a RubyLLM response message
    # so cost calculation can look up pricing.
    def extract_model_id(message)
      return message.model_id if message.respond_to?(:model_id) && message.model_id
      return message.model    if message.respond_to?(:model)    && message.model
      nil
    end

    # Show the actual tools available to the robot.
    # Only prints when --debug is enabled.
    def log_robot_tools(robot)
      return unless AIA.debug?

      local = Array(robot.local_tools).map { |t| t.respond_to?(:name) ? t.name : t.class.name }
      mcp   = Array(robot.mcp_tools).map { |t| t.respond_to?(:name) ? t.name : t.class.name }

      $stderr.puts "[DEBUG] Tool filter strategy: #{@tool_filter_strategy.active_strategy_label}"
      $stderr.puts "[DEBUG] Robot local_tools (#{local.size}): #{local.join(', ')}"
      $stderr.puts "[DEBUG] Robot mcp_tools (#{mcp.size}): #{mcp.join(', ')}"
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
