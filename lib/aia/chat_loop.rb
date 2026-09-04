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
  # :reek:TooManyInstanceVariables -- interactive-loop hub wires robot, presenter, tracker, routers, and handlers together by design
  # :reek:TooManyMethods -- one private helper per loop concern (context, metrics, speech, history)
  class ChatLoop
    include ContentExtractor
    include Speech

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
    # :reek:BooleanParameter -- lets Session skip re-sending context files after a pipeline; two entry methods would duplicate rescue/ensure
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
      files = AIA.config.context_files
      return if skip_context_files || !files || files.empty?

      context = files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return if context.empty?

      result, streamed_content, _elapsed = @streaming_runner.run(@robot, context)
      present_result(result,
                     streamed_content: streamed_content,
                     ui_presenter: @ui_presenter)
    end

    def run_loop
      loop do
        follow_up_prompt = @ui_presenter.ask_question
        break if should_exit_chat?(follow_up_prompt)

        log_user_input(follow_up_prompt)

        processed_prompt = resolve_input(follow_up_prompt)
        next if processed_prompt.nil?

        next if model_switch_handled?
        next if special_routing_handled?(processed_prompt, @robot)

        execute_and_present(processed_prompt, @robot)
        clear_turn_mcp_filter
      end
    end

    def should_exit_chat?(input)
      input.nil? || input.strip.downcase == "exit" || input.strip.empty?
    end

    def resolve_input(follow_up_prompt)
      if follow_up_prompt.strip.start_with?('/')
        resolve_directive(follow_up_prompt)
      else
        parse_prompt_string(follow_up_prompt)
      end
    end

    def resolve_directive(follow_up_prompt)
      if @directive_processor.directive?(follow_up_prompt)
        result = process_directive(follow_up_prompt)
        # A directive (e.g. /model, /config) may have rebuilt AIA.client;
        # re-bind so the next prompt uses the new model.
        rebind_robot_if_rebuilt
        result
      else
        name = follow_up_prompt.strip.split.first
        @ui_presenter.display_info("Unknown directive: #{name}  (use /help to see available directives)")
        nil
      end
    end

    def parse_prompt_string(raw)
      PM.parse_string(raw).to_s
    rescue StandardError => e
      @ui_presenter.display_info("Error: #{e.class}: #{e.message}")
      nil
    end

    def model_switch_handled?
      return false unless @model_switch_handler.handle(HandlerContext.new(config: AIA.config))

      update_robot
      true
    end

    def special_routing_handled?(processed_prompt, active_robot)
      if @special_mode_handler.handle(processed_prompt)
        clear_turn_mcp_filter
        return true
      end

      if @mention_router.handle(HandlerContext.new(robot: active_robot, prompt: processed_prompt))
        clear_turn_mcp_filter
        return true
      end

      false
    end

    def execute_and_present(processed_prompt, active_robot)
      log_robot_tools(active_robot)

      resolved_tools = @tool_filter_strategy.resolve(processed_prompt)
      if (AIA.debug? || AIA.verbose?) && resolved_tools
        puts "\nFiltered tools (#{resolved_tools.size}): #{resolved_tools.join(', ')}"
      end

      # Plain turn runs the chief directly; aggregation modes run the whole network.
      turn_target = aggregation_mode? ? active_robot : active_robot.chief
      result, streamed_content, elapsed = run_streaming_turn(turn_target, processed_prompt, resolved_tools)
      return unless result

      increment_turn_counter
      present_result(result,
                     streamed_content: streamed_content,
                     prompt: processed_prompt,
                     elapsed: elapsed,
                     ui_presenter: @ui_presenter,
                     tracker: @tracker)
    end

    def run_streaming_turn(turn_target, processed_prompt, resolved_tools)
      @streaming_runner.run(turn_target, processed_prompt, tools: resolved_tools)
    rescue StandardError => e
      @ui_presenter.display_info("Error communicating with AI: #{e.class}: #{e.message}")
      clear_turn_mcp_filter
      nil
    end

    def increment_turn_counter
      return unless @robot.respond_to?(:memory) && @robot.memory.respond_to?(:data)

      data = @robot.memory.data
      count = data.respond_to?(:turn_count) ? (data.turn_count || 0) : 0
      data.turn_count = count + 1
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

    # Re-bind @robot when a directive rebuilt AIA.client into a different robot
    # (e.g. /model). No-op when the client is unchanged or unset.
    def rebind_robot_if_rebuilt
      update_robot if AIA.client && !AIA.client.equal?(@robot)
    end

    # True when the crew should run as an aggregation network (consensus /
    # parallel / pipeline) rather than routing a plain turn to the chief.
    def aggregation_mode?
      cfg = AIA.config
      cfg.flags.consensus || Array(cfg.pipeline).length > 1 || Array(cfg.models).length > 1
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
    # :reek:TooManyStatements -- one pass builds paired metric and similarity arrays; splitting hides the pairing
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

      # active_robot is always a Network; resolve to the chief for tool inspection.
      target = robot.respond_to?(:chief) ? robot.chief : robot

      local = Array(target.local_tools).map { |t| t.respond_to?(:name) ? t.name : t.class.name }
      mcp   = Array(target.mcp_tools).map { |t| t.respond_to?(:name) ? t.name : t.class.name }

      $stderr.puts "[DEBUG] Tool filter strategy: #{@tool_filter_strategy.active_strategy_label}"
      $stderr.puts "[DEBUG] Robot local_tools (#{local.size}): #{local.join(', ')}"
      $stderr.puts "[DEBUG] Robot mcp_tools (#{mcp.size}): #{mcp.join(', ')}"
    end

    def log_user_input(input)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, "a") { |f| f.puts "\nYou: #{input}" }
    end
  end
end
