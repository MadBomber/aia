# frozen_string_literal: true

# lib/aia/pipeline_orchestrator.rb
#
# Handles per-prompt pipeline processing: building prompt text,
# executing against the robot, tracking results, and displaying output.
# Extracted from Session to separate startup concerns from per-turn concerns.

require "json"

module AIA
  class PipelineOrchestrator
    include ContentExtractor

    def initialize(robot:, prompt_handler:, input_collector:, ui_presenter:, session_tracker:, rule_router: nil)
      @robot           = robot
      @prompt_handler  = prompt_handler
      @input_collector = input_collector
      @ui              = ui_presenter
      @tracker         = session_tracker
      @rule_router     = rule_router
    end

    # Process all prompts in the pipeline.
    #
    # @param config [AIA::Config]
    def process(config)
      bridge   = TrakFlowBridge.new
      tracking = bridge.available? && config.flags.track_pipeline

      bridge.create_plan_from_pipeline(config.pipeline) if tracking

      config.pipeline.each do |prompt_id|
        next if prompt_id.nil? || prompt_id.empty?

        bridge.update_step_status(prompt_id, :started) if tracking

        prompt_text = build_prompt_text(prompt_id, config)
        next if prompt_text.nil? || prompt_text.strip.empty?

        result  = execute_prompt(prompt_text, config)
        content = extract_content(result)

        bridge.update_step_status(prompt_id, :completed) if tracking

        @tracker.record_turn(
          model:  config.models.first.name,
          input:  prompt_text,
          result: result
        )

        @ui.display_ai_response(content)
        output_to_file(content, config)
        display_metrics(result, config)
        @ui.display_separator
      rescue StandardError => e
        bridge.update_step_status(prompt_id, :failed, reason: e.message) if tracking
        raise
      end
    end

    # Allow robot to be updated (after model switch)
    attr_writer :robot

    private

    # Execute a prompt, optionally using concurrent MCP
    def execute_prompt(prompt_text, config)
      concurrent_network = maybe_use_concurrent_mcp(prompt_text, config)

      if concurrent_network
        @ui.with_spinner("Processing (concurrent)") do
          concurrent_network.run(prompt_text)
        end
      else
        @ui.with_spinner("Processing") do
          if @robot.is_a?(RobotLab::Network)
            @robot.run(message: prompt_text)
          else
            @robot.run(prompt_text, mcp: :inherit, tools: :inherit)
          end
        end
      end
    end

    # Check if concurrent MCP mode should be used
    def maybe_use_concurrent_mcp(prompt_text, config)
      return nil unless (config.mcp_servers || []).size > 1

      concurrency = config.respond_to?(:concurrency) ? config.concurrency : nil
      return nil unless concurrency&.auto || AIA.turn_state.force_concurrent_mcp

      if AIA.turn_state.force_concurrent_mcp
        AIA.turn_state.force_concurrent_mcp = false
      end

      discovery         = MCPDiscovery.new(@rule_router.decisions)
      relevant_servers  = discovery.discover(config, prompt_text)
      return nil if relevant_servers.size <= 1

      grouper = MCPGrouper.new
      groups  = grouper.group(relevant_servers)

      threshold = concurrency&.respond_to?(:threshold) ? (concurrency.threshold || 2) : 2
      return nil if groups.size < threshold

      RobotFactory.build_concurrent_mcp_network(config, groups)
    rescue StandardError => e
      warn "Warning: Concurrent MCP setup failed: #{e.message}"
      nil
    end

    # Build prompt text from a prompt_id
    def build_prompt_text(prompt_id, config)
      parsed = @prompt_handler.fetch_prompt(prompt_id)
      return nil unless parsed

      if parsed.respond_to?(:parameters) && parsed.parameters && !parsed.parameters.empty?
        values = @input_collector.collect(parsed.parameters)
        values.each { |k, v| parsed.parameters[k] = v }
      end

      prompt_text = parsed.to_s

      role = config.prompts.role
      if role && !role.empty?
        role_parsed = @prompt_handler.fetch_role(role)
        if role_parsed
          prompt_text = "#{role_parsed}\n\n#{prompt_text}"
        end
      end

      if config.stdin_content && !config.stdin_content.strip.empty?
        prompt_text = "#{prompt_text}\n\n#{config.stdin_content}"
        config.stdin_content = nil
      end

      add_context_files(prompt_text, config)
    end

    # Append context file contents to prompt
    def add_context_files(prompt_text, config)
      context_files = config.context_files
      return prompt_text if context_files.nil? || context_files.empty?

      context = context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return prompt_text if context.strip.empty?

      "#{prompt_text}\n\n#{context}"
    end

    # Display token metrics if enabled
    def display_metrics(result, config)
      return unless config.flags.tokens

      if result.respond_to?(:output) && result.output.any?
        last_msg = result.output.last
        if last_msg.respond_to?(:input_tokens)
          metrics = {
            model_id:      result.robot_name,
            input_tokens:  last_msg.input_tokens,
            output_tokens: last_msg.output_tokens
          }
          @ui.display_token_metrics(metrics)
        end
      end
    end

    # Write content to the output file if configured
    def output_to_file(content, config)
      out_file = config.output.file
      return unless out_file

      File.open(out_file, "a") do |f|
        f.puts "AI: #{content}"
      end
    end
  end
end
