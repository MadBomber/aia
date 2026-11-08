# frozen_string_literal: true

# lib/aia/pipeline_orchestrator.rb
#
# Handles per-prompt pipeline processing: building prompt text,
# executing against the robot, tracking results, and displaying output.
# Extracted from Session to separate startup concerns from per-turn concerns.

require "json"
require_relative 'skill_utils'

module AIA
  class PipelineOrchestrator
    include ContentExtractor
    include Speech
    include SkillUtils

    # :reek:LongParameterList -- collaborators injected for isolated testing
    def initialize(robot:, prompt_handler:, input_collector:, ui_presenter:, session_tracker:, robot_sync: nil)
      @robot           = robot
      @robot_sync      = robot_sync
      @prompt_handler  = prompt_handler
      @input_collector = input_collector
      @ui              = ui_presenter
      @tracker         = session_tracker
    end

    # Process all prompts in the pipeline.
    #
    # Shift-based loop: prompt front matter that sets config.pipeline
    # (`next:` or `pipeline:`) is picked up on the next iteration.
    #
    # @param config [AIA::Config]
    # :reek:DuplicateMethodCall -- config.pipeline is deliberately re-read each iteration because prompt front matter mutates it mid-loop
    def process(config)
      # Only --track-pipeline starts TrakFlow for a pipeline run. The bridge
      # does nothing when TrakFlow isn't available.
      bridge = config.flags.track_pipeline ? TrakFlowBridge.new : nil
      bridge&.create_plan_from_pipeline(config.pipeline)

      LLMErrorCollector.install!

      until config.pipeline.empty?
        prompt_id = config.pipeline.shift
        next if prompt_id.nil? || prompt_id.empty?

        run_step(prompt_id, config, bridge)
      end
    end

    # Allow robot to be updated (after model switch)
    attr_writer :robot

    # The parameter names in a PM "Missing required parameters: a, b" message.
    def self.missing_parameter_names(message)
      message.to_s.sub(/\AMissing required parameters:/, '').split(',').map(&:strip).reject(&:empty?)
    end

    private

    # Run one pipeline prompt, recording its progress on +bridge+ (a
    # TrakFlowBridge, or nil when the run isn't tracked).
    #
    # :reek:TooManyStatements -- build, sync, run, record and present one step, with its tracking interleaved
    def run_step(prompt_id, config, bridge)
      bridge&.update_step_status(prompt_id, :started)

      prompt_text = build_prompt_text(prompt_id, config)
      return if prompt_text.nil? || prompt_text.strip.empty?

      # Front matter may have changed the model or its settings
      @robot = @robot_sync.call(@robot) if @robot_sync

      LLMErrorCollector.reset!
      if special_mode_handled?(prompt_text)
        bridge&.update_step_status(prompt_id, :completed) unless llm_errors_handled?(prompt_id, bridge)
        return
      end

      result, content = compute_result(prompt_text, config)
      return if llm_errors_handled?(prompt_id, bridge)

      bridge&.update_step_status(prompt_id, :completed)

      @tracker.record_turn(model: config.models.first.name, input: prompt_text, result: result)
      present_result(content, result, config)
    rescue StandardError => e
      bridge&.update_step_status(prompt_id, :failed, reason: e.message)
      raise
    end

    # robot_lab shields a robot's exception into an "Error: ..." reply, so a
    # failed LLM call comes back looking like an answer. The collector hook
    # saw the real exception. Outside chat the step fails and aia exits 1
    # (see AIA.run); in a chat session the error is shown and the session
    # carries on. True when the step failed.
    def llm_errors_handled?(prompt_id, bridge)
      return false unless LLMErrorCollector.errors?

      message = LLMErrorCollector.message(prompt_id)
      raise AIA::LLMError, message unless AIA.chat?

      @ui.display_info(message)
      @ui.display_separator
      bridge&.update_step_status(prompt_id, :failed, reason: message)
      true
    end

    # A directive in the prompt (/debate, /verify, /decompose, /delegate,
    # /spawn, /orchestrate) asked for a special mode: hand the turn to the
    # SpecialModeHandler, as ChatLoop does. True when it ran the turn, which
    # includes displaying, saving and recording it. Concurrent MCP is left
    # to execute_prompt, which honors it alongside config.concurrency.auto.
    # A --paint step has no robot turn to hand over.
    def special_mode_handled?(prompt_text)
      return false if AIA.paint? || !special_mode_requested?

      special_mode_handler.robot = @robot
      special_mode_handler.handle(prompt_text)
    end

    # True when the turn state holds a mode for SpecialModeHandler to run.
    def special_mode_requested?
      mode = AIA.turn_state.active_mode
      !mode.nil? && mode != :concurrent_mcp
    end

    def special_mode_handler
      @special_mode_handler ||= SpecialModeHandler.new(robot: @robot, ui_presenter: @ui, tracker: @tracker)
    end

    # Show a step's response, then save and speak it. A --paint step saved
    # an image next to the output file, so there is no text to keep or speak.
    def present_result(content, result, config)
      @ui.display_ai_response(content)
      unless AIA.paint?
        output_to_file(content, config)
        speak(content)
      end
      display_metrics(result, config)
      @ui.display_separator
    end

    # Returns [result, displayable_content] for one prompt — image when in paint
    # mode, otherwise the LLM text response.
    def compute_result(prompt_text, config)
      if AIA.paint?
        image = generate_image(prompt_text, config)
        [image, image]
      else
        result = execute_prompt(prompt_text, config)
        [result, extract_content(result)]
      end
    end

    # :reek:TooManyStatements -- image request assembly, spinner-wrapped generation, then save/display of the result
    def generate_image(prompt_text, config)
      img_cfg = config.image
      quality = img_cfg.quality
      style   = img_cfg.style
      provider_options = {}
      provider_options[:quality] = quality if quality && !quality.to_s.strip.empty?
      provider_options[:style]   = style   if style   && !style.to_s.strip.empty?

      image = @ui.with_spinner("Generating image") do
        RubyLLM.paint(
          prompt_text,
          model: img_cfg.model || 'gpt-image-1',
          size:  img_cfg.size  || '1024x1024',
          provider_options:
        )
      end

      out_file = config.output.file
      if out_file
        ext  = '.png'
        path = out_file.chomp(File.extname(out_file)) + ext
        image.save(path)
        "Image saved to: #{path}"
      else
        image.url || "(image returned no URL)"
      end
    end

    # Execute a prompt, optionally using concurrent MCP
    def execute_prompt(prompt_text, config)
      concurrent_network = maybe_use_concurrent_mcp(prompt_text, config)

      if concurrent_network
        @ui.with_spinner("Processing (concurrent)") do
          concurrent_network.run(prompt_text)
        end
      else
        @ui.with_spinner("Processing") do
          @robot.run(prompt_text, mcp: :inherit, tools: :inherit)
        end
      end
    end

    # Check if concurrent MCP mode should be used
    # :reek:TooManyStatements -- ordered eligibility gates (server count, auto/forced, discovery, grouping threshold) before the build
    def maybe_use_concurrent_mcp(prompt_text, config)
      return nil unless (config.mcp_servers || []).size > 1

      turn_state  = AIA.turn_state
      concurrency = config.respond_to?(:concurrency) ? config.concurrency : nil
      return nil unless concurrency&.auto || turn_state.force_concurrent_mcp

      turn_state.clear_mode(:concurrent_mcp)

      discovery         = MCPDiscovery.new
      relevant_servers  = discovery.discover(config)
      return nil if relevant_servers.size <= 1

      grouper = MCPGrouper.new
      groups  = grouper.group(relevant_servers)

      threshold = concurrency.respond_to?(:threshold) ? (concurrency.threshold || 2) : 2
      return nil if groups.size < threshold

      RobotFactory.build_concurrent_mcp_network(config, groups)
    rescue StandardError => e
      $stderr.puts "Warning: Concurrent MCP setup failed: #{e.message}"
      nil
    end

    # Build prompt text from a prompt_id
    # :reek:TooManyStatements -- layered prompt assembly: parameters, role prefix, skills, stdin, context files, in a fixed order
    def build_prompt_text(prompt_id, config)
      parsed = @prompt_handler.fetch_prompt(prompt_id)
      return nil unless parsed

      parameters = parsed.respond_to?(:parameters) ? parsed.parameters : nil
      if parameters && !parameters.empty?
        values = @input_collector.collect(parameters)
        values.each { |k, v| parameters[k] = v }
      end

      prompt_text = render_prompt(parsed)

      role = config.prompts.role
      if role && !role.empty?
        role_parsed = @prompt_handler.fetch_role(role)
        if role_parsed
          prompt_text = "#{role_parsed}\n\n#{prompt_text}"
        end
      end

      # In pipeline mode, append --skill content to each prompt text.
      # In chat mode, skills are injected into the system prompt instead (system_prompt_assembler).
      unless config.flags&.chat == true
        skill_content = load_skills_content(
          Array(config.prompts&.skills),
          skills_base_dir(config)
        )
        prompt_text = "#{prompt_text}\n\n#{skill_content}" if skill_content
      end

      stdin_content = config.stdin_content
      if stdin_content && !stdin_content.strip.empty?
        prompt_text = "#{prompt_text}\n\n#{stdin_content}"
        config.stdin_content = nil
      end

      add_context_files(prompt_text, config)
    end

    # Render +parsed+, asking for any required parameter that only an
    # included file declares. Such a parameter is not known until the
    # include runs, so each MissingParameterError names more to ask for;
    # rendering stops retrying once it names nothing new.
    def render_prompt(parsed)
      extra = {}
      loop do
        return parsed.to_s(extra)
      rescue PM::MissingParameterError => e
        names = self.class.missing_parameter_names(e.message) - extra.keys
        raise if names.empty?

        extra.merge!(@input_collector.collect(names.to_h { [it, nil] }))
      end
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
