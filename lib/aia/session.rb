# frozen_string_literal: true

# lib/aia/session.rb
#
# Simplified orchestrator for AIA v2.
# Builds robot via RobotFactory, processes pipeline, enters chat.

require "tty-spinner"
require "tty-screen"
require "reline"
require "pm"
require "json"
require "fileutils"
require "amazing_print"
require_relative "directive_processor"
require_relative "history_manager"
require_relative "ui_presenter"
require_relative "prompt_handler"
require_relative "utility"
require_relative "input_collector"
require_relative "robot_factory"
require_relative "rule_router"
require_relative "chat_loop"

module AIA
  class Session
    def initialize(prompt_handler)
      @prompt_handler = prompt_handler

      initialize_components
      setup_output_file
    end

    # Starts the session, processing all prompts in the pipeline and then
    # optionally starting an interactive chat session.
    def start
      # Apply rules before building robot
      @rule_router.evaluate(AIA.config)

      # Build robot or network
      @robot = RobotFactory.build(AIA.config)
      AIA.client = @robot

      # Handle special chat-only cases first
      if should_start_chat_immediately?
        AIA::Utility.robot
        @chat_loop.start
        return
      end

      # Process all prompts in the pipeline
      process_pipeline

      # Start chat mode after all prompts are processed
      if AIA.chat?
        @chat_loop = ChatLoop.new(@robot, @ui_presenter, @directive_processor, @rule_router)
        AIA::Utility.robot
        @ui_presenter.display_separator
        @chat_loop.start(skip_context_files: true)
      end
    end

    private

    def initialize_components
      @ui_presenter        = UIPresenter.new
      @directive_processor = DirectiveProcessor.new
      @input_collector     = InputCollector.new
      @rule_router         = RuleRouter.new
      @chat_loop           = nil  # created after robot is built
    end

    def setup_output_file
      out_file = AIA.config.output.file
      if out_file && !out_file.nil? && !AIA.append? && File.exist?(out_file)
        File.open(out_file, "w") { }
      end
    end

    # Process all prompts in the pipeline via robot.run()
    def process_pipeline
      AIA.config.pipeline.each do |prompt_id|
        next if prompt_id.nil? || prompt_id.empty?

        prompt_text = build_prompt_text(prompt_id)
        next if prompt_text.nil? || prompt_text.strip.empty?

        result = @ui_presenter.with_spinner("Processing") { @robot.run(prompt_text, mcp: :inherit, tools: :inherit) }
        content = extract_content(result)

        @ui_presenter.display_ai_response(content)
        output_to_file(content)
        display_metrics(result)
        @ui_presenter.display_separator
      end
    end

    # Build prompt text from a prompt_id
    def build_prompt_text(prompt_id)
      parsed = @prompt_handler.fetch_prompt(prompt_id)
      return nil unless parsed

      # Collect parameter values if needed
      if parsed.respond_to?(:parameters) && parsed.parameters && !parsed.parameters.empty?
        values = @input_collector.collect(parsed.parameters)
        values.each { |k, v| parsed.parameters[k] = v }
      end

      prompt_text = parsed.to_s

      # Prepend role if configured
      role = AIA.config.prompts.role
      if role && !role.empty?
        role_parsed = @prompt_handler.fetch_role(role)
        if role_parsed
          prompt_text = "#{role_parsed}\n\n#{prompt_text}"
        end
      end

      # Append stdin content if available
      if AIA.config.stdin_content && !AIA.config.stdin_content.strip.empty?
        prompt_text = "#{prompt_text}\n\n#{AIA.config.stdin_content}"
        AIA.config.stdin_content = nil
      end

      # Append context files
      add_context_files(prompt_text)
    end

    # Append context file contents to prompt
    def add_context_files(prompt_text)
      context_files = AIA.config.context_files
      return prompt_text if context_files.nil? || context_files.empty?

      context = context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return prompt_text if context.strip.empty?

      "#{prompt_text}\n\n#{context}"
    end

    # Extract text content from a RobotResult or string
    def extract_content(result)
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

    # Display token metrics if enabled
    def display_metrics(result)
      return unless AIA.config.flags.tokens

      # Extract metrics from RobotResult if available
      if result.respond_to?(:output) && result.output.any?
        last_msg = result.output.last
        if last_msg.respond_to?(:input_tokens)
          metrics = {
            model_id: result.robot_name,
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

    # Check if we should start chat immediately without processing any prompts
    def should_start_chat_immediately?
      return false unless AIA.chat?

      # Create chat loop now that robot is available
      @chat_loop = ChatLoop.new(@robot, @ui_presenter, @directive_processor, @rule_router)

      AIA.config.pipeline.empty? || AIA.config.pipeline.all? { |id| id.nil? || id.empty? }
    end
  end
end
