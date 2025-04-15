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

      if AIA.chat? && AIA.config.prompt_id.empty?
        prompt_instance  = nil
        @history_manager = nil
      else
        prompt_instance  = @prompt_handler.get_prompt(AIA.config.prompt_id)
        @history_manager = HistoryManager.new(prompt: prompt_instance)
      end

      @context_manager = ContextManager.new(system_prompt: AIA.config.system_prompt) # Add this line
      @ui_presenter    = UIPresenter.new
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

      # Handle chat mode *only* if NO initial prompt is given
      if AIA.chat?
        AIA::Utility.robot
        if prompt_id.empty? && role_id.empty?
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

      # Determine operation type
      operation_type = @chat_processor.determine_operation_type(AIA.config.model)

      # Add initial user prompt to context *before* sending to AI
      @context_manager.add_to_context(role: 'user', content: prompt_text)

      # Process the initial prompt
      @ui_presenter.display_thinking_animation
      # Send the current context (which includes the user prompt)
      response = @chat_processor.process_prompt(@context_manager.get_context, operation_type)

      # Add AI response to context
      @context_manager.add_to_context(role: 'assistant', content: response)

      # Output the response
      @chat_processor.output_response(response) # Handles display

      # Process next prompts/pipeline (if any)
      @chat_processor.process_next_prompts(response, @prompt_handler)

      # --- Enter chat mode AFTER processing initial prompt ---
      if AIA.chat?
        @ui_presenter.display_separator # Add separator
        start_chat # start_chat will use the now populated context
      end
    end

    # Starts the interactive chat session.
    def start_chat
      # Consider if display_chat_header is needed if robot+separator already shown
      # For now, let's keep it, maybe add an indicator message
      puts "\nEntering interactive chat mode..."
      @ui_presenter.display_chat_header

      Reline::HISTORY.clear # Keep Reline history for user input editing, separate from chat context

      loop do
        # Get user input
        prompt = @ui_presenter.ask_question


        break if prompt.nil? || prompt.strip.downcase == 'exit' || prompt.strip.empty?

        if AIA.config.out_file
          File.open(AIA.config.out_file, 'a') do |file|
            file.puts "\nYou: #{prompt}"
          end
        end

        if @directive_processor.directive?(prompt)
          directive_output = @directive_processor.process(prompt, @context_manager) # Pass context_manager

          # Add check for specific directives like //clear that might modify context
          if prompt.strip.start_with?('//clear', '#!clear:')
             # Context is likely cleared within directive_processor.process now
             # or add @context_manager.clear_context here if not handled internally
             @ui_presenter.display_info("Chat context cleared.")
             next # Skip API call after clearing
          elsif directive_output.nil? || directive_output.strip.empty?
            next # Skip API call if directive produced no output and wasn't //clear
          else
            puts "\n#{directive_output}\n"
            # Optionally add directive output to context or handle as needed
            # Example: Add a summary to context
            # @context_manager.add_to_context(role: 'assistant', content: "Directive executed. Output:\n#{directive_output}")
            # For now, just use a placeholder prompt modification:
            prompt = "I executed this directive: #{prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
             # Fall through to add this modified prompt to context and send to AI
          end
        end

        # Use ContextManager instead of HistoryManager
        @context_manager.add_to_context(role: 'user', content: prompt)

        # Use ContextManager to get the conversation
        conversation = @context_manager.get_context # System prompt handled internally

        # FIXME: remove this comment once verified
        # is conversation the same thing as the context for a chat session? YES
        # if so need to somehow delete it when the //clear directive is entered. - Addressed above/in DirectiveProcessor

        operation_type = @chat_processor.determine_operation_type(AIA.config.model)
        @ui_presenter.display_thinking_animation
        response = @chat_processor.process_prompt(conversation, operation_type)

        @ui_presenter.display_ai_response(response)

        # Use ContextManager instead of HistoryManager
        @context_manager.add_to_context(role: 'assistant', content: response)

        @chat_processor.speak(response)

        @ui_presenter.display_separator
      end

      @ui_presenter.display_chat_end
    end
  end
end
