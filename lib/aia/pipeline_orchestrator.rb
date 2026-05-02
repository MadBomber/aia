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

    def initialize(robot:, prompt_handler:, input_collector:, ui_presenter:, session_tracker:)
      @robot           = robot
      @prompt_handler  = prompt_handler
      @input_collector = input_collector
      @ui              = ui_presenter
      @tracker         = session_tracker
    end

    # Process all prompts in the pipeline.
    #
    # @param config [AIA::Config]
    def process(config)
      bridge   = TrakFlowBridge.new
      tracking = bridge.available? && config.flags.track_pipeline

      bridge.create_plan_from_pipeline(config.pipeline) if tracking

      # Use shift-based loop so that prompt front matter which sets
      # config.pipeline (via `next:` or `pipeline:`) is picked up on
      # the next iteration rather than being silently ignored.
      until config.pipeline.empty?
        prompt_id = config.pipeline.shift
        next if prompt_id.nil? || prompt_id.empty?

        begin
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

      discovery         = MCPDiscovery.new
      relevant_servers  = discovery.discover(config)
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

    # Display token metrics if enabled.
    # Uses result.raw (RubyLLM::Message) for token data, matching ChatLoop's approach.
    def display_metrics(result, config)
      return unless config.flags.tokens

      if defined?(SimpleFlow::Result) && result.is_a?(SimpleFlow::Result)
        display_network_metrics(result)
        return
      end

      raw = result.respond_to?(:raw) ? result.raw : nil
      return unless raw && raw.respond_to?(:input_tokens) && raw.input_tokens

      model_id = (raw.respond_to?(:model_id) && raw.model_id) ||
                 (raw.respond_to?(:model) && raw.model) ||
                 config.models.first.name
      @ui.display_token_metrics(
        model_id:      model_id,
        input_tokens:  raw.input_tokens,
        output_tokens: raw.output_tokens
      )
    end

    def display_network_metrics(flow_result)
      metrics_list = []
      flow_result.context.each do |task_name, robot_result|
        next if task_name == :run_params
        next unless robot_result.respond_to?(:raw)

        raw = robot_result.raw
        next unless raw && raw.respond_to?(:input_tokens) && raw.input_tokens

        model_id = (raw.respond_to?(:model_id) && raw.model_id) ||
                   (raw.respond_to?(:model) && raw.model) ||
                   task_name.to_s
        display_name = robot_result.respond_to?(:robot_name) ? robot_result.robot_name : task_name.to_s
        metrics_list << {
          model_id:      model_id,
          display_name:  display_name,
          input_tokens:  raw.input_tokens || 0,
          output_tokens: raw.output_tokens || 0,
          elapsed:       robot_result.respond_to?(:duration) ? robot_result.duration : nil
        }
      end
      @ui.display_multi_model_metrics(metrics_list) unless metrics_list.empty?
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
