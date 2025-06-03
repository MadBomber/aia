# lib/aia/session.rb

require 'tty-spinner'
require 'tty-screen'
require 'reline'
require 'prompt_manager'
require 'json'
require 'fileutils'
require 'amazing_print'
require_relative 'directive_processor'
require_relative 'history_manager'
require_relative 'context_manager'
require_relative 'ui_presenter'
require_relative 'chat_processor_service'
require_relative 'prompt_handler'
require_relative 'utility'

module AIA
  class Session
    KW_HISTORY_MAX = 5 # Maximum number of history entries per keyword
    TERSE_PROMPT   = "\nKeep your response short and to the point.\n"

    def initialize(prompt_handler)
      @prompt_handler  = prompt_handler
      @chat_prompt_id = nil  # Initialize to nil

      # Special handling for chat mode with context files but no prompt ID
      if AIA.chat? && AIA.config.prompt_id.empty? && AIA.config.context_files && !AIA.config.context_files.empty?
        prompt_instance  = nil
        @history_manager = nil
      elsif AIA.chat? && AIA.config.prompt_id.empty?
        prompt_instance  = nil
        @history_manager = nil
      else
        prompt_instance  = @prompt_handler.get_prompt(AIA.config.prompt_id)
        @history_manager = HistoryManager.new(prompt: prompt_instance)
      end

      @context_manager     = ContextManager.new(system_prompt: AIA.config.system_prompt)
      @ui_presenter        = UIPresenter.new
      @directive_processor = DirectiveProcessor.new
      @chat_processor      = ChatProcessorService.new(@ui_presenter, @directive_processor)

      if AIA.config.out_file && !AIA.append? && File.exist?(AIA.config.out_file)
        File.open(AIA.config.out_file, 'w') {} # Truncate the file
      end
    end

    # Starts the session, processing the initial prompt and handling user
    # interactions. It manages the flow of prompts, context, and responses.
    def start
      prompt_id = AIA.config.prompt_id
      role_id   = AIA.config.role

      # Handle chat mode
      if AIA.chat?
        AIA::Utility.robot
        # If we're in chat mode with only context files, go straight to chat
        if prompt_id.empty? && role_id.empty? && AIA.config.context_files && !AIA.config.context_files.empty?
          start_chat
          return
        elsif prompt_id.empty? && role_id.empty?
          # Even with an empty prompt_id, we might have context files
          start_chat
          return
        end
      end


      # --- Get and process the initial prompt ---
      begin
        prompt = @prompt_handler.get_prompt(prompt_id, role_id)
      rescue StandardError => e
        puts "Error: #{e.message}"
        return
      end

      # Collect variable values if needed
      variables = prompt.parameters.keys

      if variables && !variables.empty?
        variable_values = {}
        history_manager = AIA::HistoryManager.new prompt: prompt

        variables.each do |var_name|
          # History is based on the prompt ID and the variable name (without brackets)
          history = prompt.parameters[var_name]

          # Ask the user for the variable
          value = history_manager.request_variable_value(
            variable_name:  var_name,
            history_values: history
          )
          # Store the value using the original BRACKETED key from prompt.parameters
          if history.include? value
            history.delete(value)
          end
          history << value
          if history.size > HistoryManager::MAX_VARIABLE_HISTORY
            history.shift
          end
          variable_values[var_name] = history
        end

        # Assign collected values back for prompt_manager substitution
        prompt.parameters = variable_values
      end

      # Add terse instruction if needed
      if AIA.terse?
        prompt.text << TERSE_PROMPT
      end

      prompt.save
      # Substitute variables and get final prompt text
      prompt_text = prompt.to_s

      # Add context files if any
      if AIA.config.context_files && !AIA.config.context_files.empty?
        context = AIA.config.context_files.map do |file|
          File.read(file) rescue "Error reading file: #{file}"
        end.join("\n\n")
        prompt_text = "#{prompt_text}\n\nContext:\n#{context}"
      end

      # Add initial user prompt to context *before* sending to AI
      @context_manager.add_to_context(role: 'user', content: prompt_text)

      # Process the initial prompt
      @ui_presenter.display_thinking_animation
      # Send the current context (which includes the user prompt)
      response = @chat_processor.process_prompt(@context_manager.get_context)

      # Add AI response to context
      @context_manager.add_to_context(role: 'assistant', content: response)

      # Output the response
      @chat_processor.output_response(response) # Handles display

      # Process next prompts/pipeline (if any)
      @chat_processor.process_next_prompts(response, @prompt_handler)

      # --- Enter chat mode AFTER processing initial prompt ---
      if AIA.chat?
        @ui_presenter.display_separator # Add separator
        start_chat(skip_context_files: true) # start_chat will use the now populated context
      end
    end

    # Starts the interactive chat session.
    # NOTE: there could have been an initial prompt sent into this session
    #       via a prompt_id on the command line, piped in text, or context files.
    def start_chat(skip_context_files: false)
      puts "\nEntering interactive chat mode..."
      @ui_presenter.display_chat_header

      # Generate chat prompt ID
      now = Time.now
      @chat_prompt_id = "chat_#{now.strftime('%Y%m%d_%H%M%S')}"

      # Create the temporary prompt
      begin
        # Create the unique? prompt ID in the file storage system with its initial text
        PromptManager::Prompt.create(
          id: @chat_prompt_id,
          text: "Today's date is #{now.strftime('%Y-%m-%d')} and the current time is #{now.strftime('%H:%M:%S')}"
        )

        # Capture self for the handlers
        session_instance = self

        # Set up cleanup handlers only after prompt is created
        at_exit { session_instance.send(:cleanup_chat_prompt) }
        Signal.trap('INT') {
          session_instance.send(:cleanup_chat_prompt)
          exit
        }

        # Access this chat session's prompt object in order to do the dynamic things
        # in follow up prompts that can be done in the batch mode like shell substitution. etc.
        @chat_prompt = PromptManager::Prompt.new(
          id: @chat_prompt_id,
          directives_processor: @directive_processor,
          erb_flag:             true,
          envar_flag:           true,
          external_binding:     binding,
        )

        Reline::HISTORY.clear

        # Load context files if any and not skipping
        if !skip_context_files && AIA.config.context_files && !AIA.config.context_files.empty?
          context = AIA.config.context_files.map do |file|
            File.read(file) rescue "Error reading file: #{file}"
          end.join("\n\n")

          if !context.empty?
            # Add context files content to context
            @context_manager.add_to_context(role: 'user', content: context)

            # Process the context
            @ui_presenter.display_thinking_animation
            response = @chat_processor.process_prompt(@context_manager.get_context)

            # Add AI response to context
            @context_manager.add_to_context(role: 'assistant', content: response)

            # Output the response
            @chat_processor.output_response(response)
            @chat_processor.speak(response)
            @ui_presenter.display_separator
          end
        end

        # Handle piped input
        if !STDIN.tty?
          original_stdin = STDIN.dup
          piped_input = STDIN.read.strip
          STDIN.reopen('/dev/tty')

          if !piped_input.empty?
            @chat_prompt.text = piped_input
            processed_input = @chat_prompt.to_s

            @context_manager.add_to_context(role: 'user', content: processed_input)

            @ui_presenter.display_thinking_animation
            response = @chat_processor.process_prompt(@context_manager.get_context)

            @context_manager.add_to_context(role: 'assistant', content: response)
            @chat_processor.output_response(response)
            @chat_processor.speak(response) if AIA.speak?
            @ui_presenter.display_separator
          end

          STDIN.reopen(original_stdin)
        end

        # Main chat loop
        loop do
          follow_up_prompt = @ui_presenter.ask_question

          break if follow_up_prompt.nil? || follow_up_prompt.strip.downcase == 'exit' || follow_up_prompt.strip.empty?

          if AIA.config.out_file
            File.open(AIA.config.out_file, 'a') do |file|
              file.puts "\nYou: #{follow_up_prompt}"
            end
          end

          if @directive_processor.directive?(follow_up_prompt)
            directive_output = @directive_processor.process(follow_up_prompt, @context_manager)

            if follow_up_prompt.strip.start_with?('//clear')
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
               next
            elsif directive_output.nil? || directive_output.strip.empty?
              next
            else
              puts "\n#{directive_output}\n"
              follow_up_prompt = "I executed this directive: #{follow_up_prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
            end
          end

          @chat_prompt.text = follow_up_prompt
          processed_prompt = @chat_prompt.to_s

          @context_manager.add_to_context(role: 'user', content: processed_prompt)
          conversation = @context_manager.get_context

          @ui_presenter.display_thinking_animation
          response = @chat_processor.process_prompt(conversation)

          @ui_presenter.display_ai_response(response)
          @context_manager.add_to_context(role: 'assistant', content: response)
          @chat_processor.speak(response)

          @ui_presenter.display_separator
        end

      ensure
        @ui_presenter.display_chat_end
      end
    end

    private

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
