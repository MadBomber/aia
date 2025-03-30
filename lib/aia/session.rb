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

module AIA
  class Session
    KW_HISTORY_MAX = 5 # Maximum number of history entries per keyword



    def initialize(prompt_handler, client)
      @prompt_handler  = prompt_handler
      @client          = client
      @history_manager = HistoryManager.new
      @ui_presenter    = UIPresenter.new
      @directive_processor = DirectiveProcessor.new
      @chat_processor      = ChatProcessorService.new(client, @ui_presenter, @directive_processor)

      if AIA.config.out_file && !AIA.append? && File.exist?(AIA.config.out_file)
        File.open(AIA.config.out_file, 'w') {} # Truncate the file
      end
    end

    # Starts the session, processing the initial prompt and handling user
    # interactions. It manages the flow of prompts, context, and responses.
    def start
      prompt_id = AIA.config.prompt_id
      role_id   = AIA.config.role

      # If directly starting in chat mode with empty prompt_id and no role
      if AIA.chat? && prompt_id.empty? && !role_id
        start_chat
        return
      end

      if AIA.chat? && role_id && (!prompt_id || prompt_id.empty?)
        start_chat_with_role(role_id)
        return
      end

      prompt  = PromptManager::Prompt.get(
                  id:                  prompt_id,
                  shell_flag:          AIA.shell?,
                  erb_flag:            AIA.erb?,
                  directive_processor: AIA::DirectiveProcessor.new,
                  external_binding:    binding
                ) rescue nil

      if prompt.nil?
        puts "Error: Could not find prompt with ID: #{prompt_id}"
        return
      end

      if role_id
        role_prompt = PromptManager::Prompt.get(
                        id:                  role_id,
                        shell_flag:          AIA.shell?,
                        erb_flag:            AIA.erb?,
                        directive_processor: AIA::DirectiveProcessor.new,
                        external_binding:    binding
                      ) rescue nil

        if role_prompt
          prompt.text = "#{role_prompt.text}\n#{prompt.text}"
        else
          puts "Warning: Could not find role with ID: #{role_id}"
        end
      end

      variables = prompt.keywords

      if variables && !variables.empty?
        variable_values = {}
        history         = @history_manager.load_variable_history
        prompt_history  = history[prompt_id] || {}

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

      prompt_text = prompt.text





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

        break if prompt.nil? || prompt.strip.downcase == 'exit'

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

        prompt = @chat_processor.process_dynamic_content(prompt)

        @history_manager.add_to_history('user', prompt)

        conversation = @history_manager.build_conversation_context(prompt, @config.system_prompt)

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


    def start_chat_with_role(role_id)
      # Add 'roles/' prefix to role_id if it doesn't already have it
      roles = AIA.config.roles_dir.split('/').last
      role_path = role_id.start_with?(roles+'/') ? role_id : "roles/#{role_id}"

      role_prompt = PromptManager::Prompt.get(
                      id:                  role_path,
                      shell_flag:          AIA.shell?,
                      erb_flag:            AIA.erb?,
                      directive_processor: AIA::DirectiveProcessor.new,
                      external_binding:    binding
                    ) rescue nil

      if role_prompt.nil?
        puts "Error: Could not find role with ID: #{role_id}"
        return
      end

      AIA.config.system_prompt = role_path

      start_chat
    end
  end
end
