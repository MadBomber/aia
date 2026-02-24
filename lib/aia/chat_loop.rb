# frozen_string_literal: true

# lib/aia/chat_loop.rb
#
# Thin interactive chat shell for AIA v2.
# Uses robot.run(input) for AI interaction — robot maintains
# conversation history internally via its persistent RubyLLM::Chat.
# Integrates model switching, expert routing, verification,
# decomposition, and session tracking.

require "reline"
require "pm"

module AIA
  class ChatLoop
    def initialize(robot, ui_presenter, directive_processor, rule_router,
                   session_tracker: nil, alias_registry: nil)
      @robot               = robot
      @ui_presenter        = ui_presenter
      @directive_processor = directive_processor
      @rule_router         = rule_router
      @tracker             = session_tracker || SessionTracker.new
      @alias_registry      = alias_registry || ModelAliasRegistry.new
      @model_switch_handler = ModelSwitchHandler.new(@alias_registry, @ui_presenter)
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
      initialize_ui
      setup_signals
      Reline::HISTORY.clear
    end

    def initialize_ui
      puts "\nEntering interactive chat mode..."
      @ui_presenter.display_chat_header
    end

    def setup_signals
      Signal.trap("INT") { exit }
    end

    def process_initial_context(skip_context_files)
      return if skip_context_files || !AIA.config.context_files || AIA.config.context_files.empty?

      context = AIA.config.context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return if context.empty?

      result, streamed_content = run_with_streaming(context)
      content = streamed_content || extract_content(result)

      if streamed_content
        puts  # newline after streamed content
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

        if @directive_processor.directive?(follow_up_prompt)
          follow_up_prompt = process_directive(follow_up_prompt)
          next if follow_up_prompt.nil?
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
          @robot = AIA.client  # Robot was rebuilt
          next
        end

        # Check for special execution modes
        if handle_special_modes(processed_prompt)
          next
        end

        # Expert routing (per-turn specialist)
        if AIA.config.flags.expert_routing
          specialist = route_to_expert(decisions, processed_prompt)
          next if specialist
        end

        begin
          result, streamed_content = run_with_streaming(processed_prompt)
        rescue StandardError => e
          @ui_presenter.display_info("Error communicating with AI: #{e.class}: #{e.message}")
          next
        end

        content = streamed_content || extract_content(result)

        # Track the turn
        @tracker.record_turn(
          model: AIA.config.models.first.name,
          input: processed_prompt,
          result: result,
          decisions: decisions
        )

        # Run post-response learning
        @rule_router.evaluate_response(AIA.config, { accepted: true, model: AIA.config.models.first.name })

        if streamed_content
          puts  # newline after streamed content
        else
          @ui_presenter.display_ai_response(content)
        end
        output_to_file(content)
        display_metrics(result)
        speak(content)
        @ui_presenter.display_separator
      end
    end

    # Handle /concurrent, /verify, /decompose modes
    def handle_special_modes(prompt)
      handled = false

      if AIA.config.instance_variable_defined?(:@force_verify) && AIA.config.instance_variable_get(:@force_verify)
        AIA.config.remove_instance_variable(:@force_verify)
        handled = handle_verification(prompt)
      end

      if !handled && AIA.config.instance_variable_defined?(:@force_decompose) && AIA.config.instance_variable_get(:@force_decompose)
        AIA.config.remove_instance_variable(:@force_decompose)
        handled = handle_decomposition(prompt)
      end

      if !handled && AIA.config.instance_variable_defined?(:@force_concurrent_mcp) && AIA.config.instance_variable_get(:@force_concurrent_mcp)
        AIA.config.remove_instance_variable(:@force_concurrent_mcp)
        handled = handle_concurrent_mcp(prompt)
      end

      handled
    end

    def handle_verification(prompt)
      @ui_presenter.display_info("Running verification (2 independent + reconciliation)...")

      begin
        network = VerificationNetwork.build(AIA.config)
        result = @ui_presenter.with_spinner("Verifying") { network.run(prompt) }
        content = extract_content(result)

        @tracker.record_turn(model: AIA.config.models.first.name, input: prompt, result: result)
        @ui_presenter.display_ai_response(content)
        output_to_file(content)
        @ui_presenter.display_separator
        true
      rescue StandardError => e
        @ui_presenter.display_info("Verification failed: #{e.message}. Falling back to normal mode.")
        false
      end
    end

    def handle_decomposition(prompt)
      @ui_presenter.display_info("Decomposing prompt into sub-tasks...")

      decomposer = PromptDecomposer.new(@robot)
      subtasks = decomposer.decompose(prompt)

      if subtasks.empty?
        @ui_presenter.display_info("Prompt cannot be meaningfully decomposed. Running normally.")
        return false
      end

      @ui_presenter.display_info("Decomposed into #{subtasks.size} sub-tasks:")
      subtasks.each_with_index { |t, i| @ui_presenter.display_info("  #{i + 1}. #{t}") }

      results = subtasks.map.with_index do |task, i|
        @ui_presenter.display_info("Processing sub-task #{i + 1}...")
        r = if @robot.is_a?(RobotLab::Network)
              @robot.run(message: task)
            else
              @robot.run(task, mcp: :inherit, tools: :inherit)
            end
        extract_content(r)
      end

      @ui_presenter.display_info("Synthesizing results...")
      final = decomposer.synthesize(prompt, results)
      content = extract_content(final)

      @tracker.record_turn(model: AIA.config.models.first.name, input: prompt, result: final)
      @ui_presenter.display_ai_response(content)
      output_to_file(content)
      @ui_presenter.display_separator
      true
    rescue StandardError => e
      @ui_presenter.display_info("Decomposition failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def handle_concurrent_mcp(prompt)
      return false unless (AIA.config.mcp_servers || []).size > 1

      discovery = MCPDiscovery.new(@rule_router)
      relevant = discovery.discover(AIA.config, prompt)
      return false if relevant.size <= 1

      grouper = MCPGrouper.new
      groups = grouper.group(relevant)
      return false if groups.size < 2

      @ui_presenter.display_info("Running concurrent MCP across #{groups.size} server groups...")

      network = RobotFactory.build_concurrent_mcp_network(AIA.config, groups)
      result = @ui_presenter.with_spinner("Processing (concurrent)") { network.run(prompt) }
      content = extract_content(result)

      @tracker.record_turn(model: AIA.config.models.first.name, input: prompt, result: result)
      @ui_presenter.display_ai_response(content)
      output_to_file(content)
      @ui_presenter.display_separator
      true
    rescue StandardError => e
      @ui_presenter.display_info("Concurrent MCP failed: #{e.message}. Falling back to normal mode.")
      false
    end

    def route_to_expert(decisions, prompt)
      router = ExpertRouter.new(decisions)
      specialist = router.route(AIA.config)
      return nil unless specialist

      @ui_presenter.display_info("Routing to specialist: #{specialist.respond_to?(:name) ? specialist.name : 'expert'}")

      result, streamed_content = nil, nil

      begin
        spinner = TTY::Spinner.new("[:spinner] Expert processing...", format: :bouncing_ball)
        spinner.auto_spin
        streamed = []
        header_printed = false

        result = specialist.run(prompt, mcp: :inherit, tools: :inherit) do |chunk|
          text = chunk.respond_to?(:content) ? chunk.content.to_s : chunk.to_s
          next if text.empty?

          unless header_printed
            spinner.stop
            print "\nAI (Expert):\n   "
            header_printed = true
          end

          streamed << text
          $stdout.print(text)
        end

        spinner.stop unless header_printed
        streamed_content = streamed.empty? ? nil : streamed.join
      rescue StandardError => e
        @ui_presenter.display_info("Expert routing failed: #{e.message}")
        return nil
      end

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
    end

    def process_directive(follow_up_prompt)
      directive_output = @directive_processor.process(follow_up_prompt, nil)

      if follow_up_prompt.strip.start_with?("/clear", "/checkpoint", "/restore", "/review", "/context")
        @ui_presenter.display_info(directive_output) unless directive_output.nil? || directive_output.strip.empty?
        return nil
      end

      return nil if directive_output.nil? || directive_output.strip.empty?

      handle_successful_directive(follow_up_prompt, directive_output)
    end

    def handle_successful_directive(follow_up_prompt, directive_output)
      puts "\n#{directive_output}\n"
      "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
    end

    # Run robot with streaming: spinner shows until first chunk arrives,
    # then spinner stops and chunks are printed directly.
    # Returns [result, streamed_content] where streamed_content is the
    # concatenated text if streaming occurred, or nil if it didn't.
    def run_with_streaming(prompt)
      spinner = TTY::Spinner.new("[:spinner] Processing...", format: :bouncing_ball)
      spinner.auto_spin
      streamed = []
      header_printed = false

      streaming_block = proc do |chunk|
        text = chunk.respond_to?(:content) ? chunk.content.to_s : chunk.to_s
        next if text.empty?

        unless header_printed
          spinner.stop
          print "\nAI:\n   "
          header_printed = true
        end

        streamed << text
        $stdout.print(text)
      end

      result = if @robot.is_a?(RobotLab::Network)
                 @robot.run(message: prompt)
               else
                 @robot.run(prompt, mcp: :inherit, tools: :inherit, &streaming_block)
               end

      spinner.stop unless header_printed

      content = streamed.empty? ? nil : streamed.join
      [result, content]
    end

    # Extract text content from a RobotResult, SimpleFlow::Result, or string
    def extract_content(result)
      # Network returns SimpleFlow::Result — extract from context
      if result.is_a?(SimpleFlow::Result)
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
        parts << "**#{task_name}:**\n#{content}" if content && !content.empty?
      end
      parts.join("\n\n")
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

    # Write content to output file
    def output_to_file(content)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, 'a') do |file|
        file.puts "\nAI: #{content}"
      end
    end

    # Log user input to output file
    def log_user_input(input)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, "a") do |file|
        file.puts "\nYou: #{input}"
      end
    end

    # Speak the content if speak mode is enabled
    def speak(content)
      return unless AIA.speak?

      begin
        command = AIA.config.audio.speak_command || 'say'
        system(command, content.to_s)
      rescue StandardError => e
        warn "Warning: Speech failed: #{e.message}"
      end
    end
  end
end
