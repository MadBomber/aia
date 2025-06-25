# lib/aia/session.rb

require "tty-spinner"
require "tty-screen"
require "reline"
require "prompt_manager"
require "json"
require "fileutils"
require "amazing_print"
require_relative "directive_processor"
require_relative "history_manager"
require_relative "context_manager"
require_relative "ui_presenter"
require_relative "chat_processor_service"
require_relative "prompt_handler"
require_relative "utility"

module AIA
  class Session
    KW_HISTORY_MAX = 5 # Maximum number of history entries per keyword
    TERSE_PROMPT = "\nKeep your response short and to the point.\n"

    def initialize(prompt_handler)
      @prompt_handler = prompt_handler
      @chat_prompt_id = nil
      @include_context_flag = true
      
      setup_prompt_and_history_manager
      initialize_components
      setup_output_file
    end

    def setup_prompt_and_history_manager
      # Special handling for chat mode with context files but no prompt ID
      if AIA.chat? && (AIA.config.prompt_id.nil? || AIA.config.prompt_id.empty?) && AIA.config.context_files && !AIA.config.context_files.empty?
        prompt_instance = nil
        @history_manager = nil
      elsif AIA.chat? && (AIA.config.prompt_id.nil? || AIA.config.prompt_id.empty?)
        prompt_instance = nil
        @history_manager = nil
      else
        prompt_instance = @prompt_handler.get_prompt(AIA.config.prompt_id)
        @history_manager = HistoryManager.new(prompt: prompt_instance)
      end
    end

    def initialize_components
      @context_manager = ContextManager.new(system_prompt: AIA.config.system_prompt)
      @ui_presenter = UIPresenter.new
      @directive_processor = DirectiveProcessor.new
      @chat_processor = ChatProcessorService.new(@ui_presenter, @directive_processor)
    end

    def setup_output_file
      if AIA.config.out_file && !AIA.config.out_file.nil? && !AIA.append? && File.exist?(AIA.config.out_file)
        File.open(AIA.config.out_file, "w") { } # Truncate the file
      end
    end

    # Starts the session, processing all prompts in the pipeline and then
    # optionally starting an interactive chat session.
    def start
      # Handle special chat-only cases first
      if should_start_chat_immediately?
        AIA::Utility.robot
        start_chat
        return
      end

      # Process all prompts in the pipeline
      process_all_prompts

      # Start chat mode after all prompts are processed
      if AIA.chat?
        AIA::Utility.robot
        @ui_presenter.display_separator
        start_chat(skip_context_files: true)
      end
    end

    private

    # Check if we should start chat immediately without processing any prompts
    def should_start_chat_immediately?
      return false unless AIA.chat?

      # If pipeline is empty or only contains empty prompt_ids, go straight to chat
      AIA.config.pipeline.empty? || AIA.config.pipeline.all? { |id| id.nil? || id.empty? }
    end

    # Process all prompts in the pipeline sequentially
    def process_all_prompts
      prompt_count = 0
      total_prompts = AIA.config.pipeline.size

      until AIA.config.pipeline.empty?
        prompt_count += 1
        prompt_id = AIA.config.pipeline.shift

        puts "\n--- Processing prompt #{prompt_count}/#{total_prompts}: #{prompt_id} ---" if AIA.verbose? && total_prompts > 1

        process_single_prompt(prompt_id)
      end
    end

    # Process a single prompt with all its requirements
    def process_single_prompt(prompt_id)
      # Skip empty prompt IDs
      return if prompt_id.nil? || prompt_id.empty?

      prompt = setup_prompt_processing(prompt_id)
      return unless prompt

      prompt_text = finalize_prompt_text(prompt)
      send_prompt_and_get_response(prompt_text)
    end

    def setup_prompt_processing(prompt_id)
      role_id = AIA.config.role

      begin
        prompt = @prompt_handler.get_prompt(prompt_id, role_id)
      rescue StandardError => e
        puts "Error processing prompt '#{prompt_id}': #{e.message}"
        return nil
      end

      if @include_context_flag
        collect_variable_values(prompt)
        enhance_prompt_with_extras(prompt)
      end

      prompt
    end

    def finalize_prompt_text(prompt)
      prompt_text = prompt.to_s

      if @include_context_flag
        prompt_text = add_context_files(prompt_text)
        # SMELL: TODO? empty the AIA.config.context_files array
        @include_context_flag = false
      end

      prompt_text
    end

    # Collect variable values from user input
    def collect_variable_values(prompt)
      variables = prompt.parameters.keys
      return if variables.nil? || variables.empty?

      variable_values = {}
      history_manager = AIA::HistoryManager.new prompt: prompt

      variables.each do |var_name|
        history = prompt.parameters[var_name]

        value = history_manager.request_variable_value(
          variable_name: var_name,
          history_values: history,
        )

        variable_values[var_name] = update_variable_history(history, value)
      end

      prompt.parameters = variable_values
    end

    def update_variable_history(history, value)
      history.delete(value) if history.include?(value)
      history << value
      history.shift if history.size > HistoryManager::MAX_VARIABLE_HISTORY
      history
    end

    # Add terse instructions, stdin content, and executable prompt file content
    def enhance_prompt_with_extras(prompt)
      # Add terse instruction if needed
      prompt.text << TERSE_PROMPT if AIA.terse?

      # Add STDIN content
      if AIA.config.stdin_content && !AIA.config.stdin_content.strip.empty?
        prompt.text << "\n\n" << AIA.config.stdin_content
      end

      # Add executable prompt file content
      if AIA.config.executable_prompt_file
        prompt.text << "\n\n" << File.read(AIA.config.executable_prompt_file)
          .lines[1..]
          .join
      end
    end

    # Add context files to prompt text
    def add_context_files(prompt_text)
      return prompt_text unless AIA.config.context_files && !AIA.config.context_files.empty?

      context = AIA.config.context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      "#{prompt_text}\n\nContext:\n#{context}"
    end

    # Send prompt to AI and handle the response
    def send_prompt_and_get_response(prompt_text)
      # Add prompt to conversation context
      @context_manager.add_to_context(role: "user", content: prompt_text)

      # Process the prompt
      @ui_presenter.display_thinking_animation
      response = @chat_processor.process_prompt(@context_manager.get_context)

      # Add AI response to context
      @context_manager.add_to_context(role: "assistant", content: response)

      # Output the response
      @chat_processor.output_response(response)

      # Process any directives in the response
      if @directive_processor.directive?(response)
        directive_result = @directive_processor.process(response, @context_manager)
        puts "\nDirective output: #{directive_result}" if directive_result && !directive_result.strip.empty?
      end
    end

    # Starts the interactive chat session.
    # NOTE: there could have been an initial prompt sent into this session
    #       via a prompt_id on the command line, piped in text, or context files.
    def start_chat(skip_context_files: false)
      setup_chat_session
      process_initial_context(skip_context_files)
      handle_piped_input
      run_chat_loop
    ensure
      @ui_presenter.display_chat_end
    end

    private

    def setup_chat_session
      initialize_chat_ui
      @chat_prompt_id = generate_chat_prompt_id
      create_temporary_prompt
      setup_signal_handlers
      create_chat_prompt_object
      Reline::HISTORY.clear
    end

    def initialize_chat_ui
      puts "\nEntering interactive chat mode..."
      @ui_presenter.display_chat_header
    end

    def generate_chat_prompt_id
      now = Time.now
      "chat_#{now.strftime("%Y%m%d_%H%M%S")}"
    end

    def create_temporary_prompt
      now = Time.now
      PromptManager::Prompt.create(
        id: @chat_prompt_id,
        text: "Today's date is #{now.strftime("%Y-%m-%d")} and the current time is #{now.strftime("%H:%M:%S")}",
      )
    end

    def setup_signal_handlers
      session_instance = self
      at_exit { session_instance.send(:cleanup_chat_prompt) }
      Signal.trap("INT") {
        session_instance.send(:cleanup_chat_prompt)
        exit
      }
    end

    def create_chat_prompt_object
      @chat_prompt = PromptManager::Prompt.new(
        id: @chat_prompt_id,
        directives_processor: @directive_processor,
        erb_flag: true,
        envar_flag: true,
        external_binding: binding,
      )
    end

    def process_initial_context(skip_context_files)
      return if skip_context_files || !AIA.config.context_files || AIA.config.context_files.empty?

      context = AIA.config.context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      return if context.empty?

      # Add context files content to context
      @context_manager.add_to_context(role: "user", content: context)

      # Process the context
      @ui_presenter.display_thinking_animation
      response = @chat_processor.process_prompt(@context_manager.get_context)

      # Add AI response to context
      @context_manager.add_to_context(role: "assistant", content: response)

      # Output the response
      @chat_processor.output_response(response)
      @chat_processor.speak(response)
      @ui_presenter.display_separator
    end

    def handle_piped_input
      return if STDIN.tty?

      original_stdin = STDIN.dup
      piped_input = STDIN.read.strip
      STDIN.reopen("/dev/tty")

      return if piped_input.empty?

      @chat_prompt.text = piped_input
      processed_input = @chat_prompt.to_s

      @context_manager.add_to_context(role: "user", content: processed_input)

      @ui_presenter.display_thinking_animation
      response = @chat_processor.process_prompt(@context_manager.get_context)

      @context_manager.add_to_context(role: "assistant", content: response)
      @chat_processor.output_response(response)
      @chat_processor.speak(response) if AIA.speak?
      @ui_presenter.display_separator

      STDIN.reopen(original_stdin)
    end

    def run_chat_loop
      loop do
        follow_up_prompt = @ui_presenter.ask_question

        break if follow_up_prompt.nil? || follow_up_prompt.strip.downcase == "exit" || follow_up_prompt.strip.empty?

        if AIA.config.out_file
          File.open(AIA.config.out_file, "a") do |file|
            file.puts "\nYou: #{follow_up_prompt}"
          end
        end

        if @directive_processor.directive?(follow_up_prompt)
          follow_up_prompt = process_chat_directive(follow_up_prompt)
          next if follow_up_prompt.nil?
        end

        @chat_prompt.text = follow_up_prompt
        processed_prompt = @chat_prompt.to_s

        @context_manager.add_to_context(role: "user", content: processed_prompt)
        conversation = @context_manager.get_context

        @ui_presenter.display_thinking_animation
        response = @chat_processor.process_prompt(conversation)

        @ui_presenter.display_ai_response(response)
        @context_manager.add_to_context(role: "assistant", content: response)
        @chat_processor.speak(response)

        @ui_presenter.display_separator
      end
    end

    def process_chat_directive(follow_up_prompt)
      directive_output = @directive_processor.process(follow_up_prompt, @context_manager)
      
      return handle_clear_directive if follow_up_prompt.strip.start_with?("//clear")
      return handle_empty_directive_output if directive_output.nil? || directive_output.strip.empty?
      
      handle_successful_directive(follow_up_prompt, directive_output)
    end

    def handle_clear_directive
      # The directive processor has called context_manager.clear_context
      # but we need a more aggressive approach to fully clear all context

      # First, clear the context manager's context
      @context_manager.clear_context(keep_system_prompt: true)

      # Second, try clearing the client's context
      if AIA.config.client && AIA.config.client.respond_to?(:clear_context)
        AIA.config.client.clear_context
      end

      # Third, completely reinitialize the client to ensure fresh state
      # This is the most aggressive approach to ensure no context remains
      begin
        AIA.config.client = AIA::RubyLLMAdapter.new
      rescue => e
        STDERR.puts "Error reinitializing client: #{e.message}"
      end

      @ui_presenter.display_info("Chat context cleared.")
      nil
    end

    def handle_empty_directive_output
      nil
    end

    def handle_successful_directive(follow_up_prompt, directive_output)
      puts "\n#{directive_output}\n"
      "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
    end

    def cleanup_chat_prompt
      if @chat_prompt_id
        puts "[DEBUG] Cleaning up chat prompt: #{@chat_prompt_id}" if AIA.debug?
        begin
          @chat_prompt.delete
          @chat_prompt_id = nil # Prevent repeated attempts if error occurs elsewhere
        rescue => e
          STDERR.puts "[ERROR] Failed to delete chat prompt #{@chat_prompt_id}: #{e.class} - #{e.message}"
          STDERR.puts e.backtrace.join("\n")
        end
      end
    end
  end
end
