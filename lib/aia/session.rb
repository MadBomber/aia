# lib/aia/session.rb
# frozen_string_literal: true

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
require_relative "chat_processor_service"
require_relative "prompt_handler"
require_relative "utility"
require_relative "input_collector"
require_relative "prompt_pipeline"
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
      # Handle special chat-only cases first
      if should_start_chat_immediately?
        AIA::Utility.robot
        @chat_loop.start
        return
      end

      # Process all prompts in the pipeline
      @prompt_pipeline.process_all

      # Start chat mode after all prompts are processed
      if AIA.chat?
        AIA::Utility.robot
        @ui_presenter.display_separator
        @chat_loop.start(skip_context_files: true)
      end
    end

    private

    def initialize_components
      @ui_presenter        = UIPresenter.new
      @directive_processor = DirectiveProcessor.new
      @chat_processor      = ChatProcessorService.new(@ui_presenter, @directive_processor)
      @input_collector     = InputCollector.new
      @prompt_pipeline     = PromptPipeline.new(@prompt_handler, @chat_processor, @ui_presenter, @input_collector)
      @chat_loop           = ChatLoop.new(@chat_processor, @ui_presenter, @directive_processor)
    end

    def setup_output_file
      out_file = AIA.config.output.file
      if out_file && !out_file.nil? && !AIA.append? && File.exist?(out_file)
        File.open(out_file, "w") { } # Truncate the file
      end
    end

    # Check if we should start chat immediately without processing any prompts
    def should_start_chat_immediately?
      return false unless AIA.chat?

      AIA.config.pipeline.empty? || AIA.config.pipeline.all? { |id| id.nil? || id.empty? }
    end
  end
end
