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
require_relative 'ui_presenter'
require_relative 'chat_processor_service'
require_relative 'prompt_handler'

module AIA
  class Session
    KW_HISTORY_MAX = 5 # Maximum number of history entries per keyword
    TERSE_PROMPT   = "\nKeep your response short and to the point.\n"

    def initialize(prompt_handler)
      @prompt_handler  = prompt_handler
      @history_manager = HistoryManager.new
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

      # If directly starting in chat mode without any initial prompting
      if AIA.chat? && prompt_id.empty? && role_id.empty?
        start_chat
        return
      end

      begin
        prompt = @prompt_handler.get_prompt(prompt_id, role_id)
      rescue StandardError => e
        puts "Error: #{e.message}"
        return
      end

      variables = prompt.parameters.keys

      if variables && !variables.empty?
        variable_values = {}

        variables.each do |variable|
          var_history = @history_manager.get_variable_history(prompt_id, variable)

          @history_manager.setup_variable_history(var_history)

          default = var_history.last

          puts "\nParameter [#{variable}] ..."
          $stdout.flush

          prompt_text = if default.nil? || default.empty?
                          "> "
                        else
                          "(#{default}) > "
                        end

          value = Reline.readline(prompt_text, true).strip

          value = default if value.empty? && !default.nil?

          variable_values[variable] = value

          @history_manager.get_variable_history(prompt_id, variable, value)
        end

        prompt.parameters = variable_values
      end

      if AIA.terse?
        prompt.text << TERSE_PROMPT
      end

      prompt_text = prompt.to_s

      # Add context files if any
      if AIA.config.context_files && !AIA.config.context_files.empty?
        context = AIA.config.context_files.map do |file|
          File.read(file) rescue "Error reading file: #{file}"
        end.join("\n\n")

        prompt_text = "#{prompt_text}\n\nContext:\n#{context}"
      end

      # Determine the type of operation based on the model
      operation_type = @chat_processor.determine_operation_type(AIA.config.model)

      # Process the prompt based on the operation type
      response = @chat_processor.process_prompt(prompt_text, operation_type)

      # Handle output
      @chat_processor.output_response(response)

      # Process next prompt or pipeline if specified
      @chat_processor.process_next_prompts(response, @prompt_handler)

      # Enter chat mode if requested
      start_chat if AIA.chat?
    end


    def start_chat
      @ui_presenter.display_chat_header

      Reline::HISTORY.clear

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
          directive_output = @directive_processor.process(prompt)

          if directive_output.nil? || directive_output.strip.empty?
            next
          else
            puts "\n#{directive_output}\n"
            prompt = "I executed this directive: #{prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
          end
        end

        @history_manager.add_to_history('user', prompt)

        conversation = @history_manager.build_conversation_context(prompt, AIA.config.system_prompt)

        # FIXME: is conversation the same thing as the context for a chat session?
        #        if so need to somehow delete it when the //clear directive is entered.

        operation_type = @chat_processor.determine_operation_type(AIA.config.model)
        @ui_presenter.display_thinking_animation
        response = @chat_processor.process_prompt(conversation, operation_type)

        @ui_presenter.display_ai_response(response)

        @history_manager.add_to_history('assistant', response)

        @chat_processor.speak(response)

        @ui_presenter.display_separator
      end

      @ui_presenter.display_chat_end
    end
  end
end
