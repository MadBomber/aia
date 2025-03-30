# lib/aia/session.rb
#
# This file manages the session logic for the AIA application.
# The Session class manages the interactive session logic for the AIA
# application. It handles user input, prompt processing, and interaction
# with the AI client.

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
  # The Session class manages the interactive session logic for the AIA
  # application. It handles user input, prompt processing, and interaction
  # with the AI client.
  class Session
    KW_HISTORY_MAX = 5 # Maximum number of history entries per keyword

    # Initializes a new session with the given configuration, prompt handler,
    # and AI client.
    #
    # @param config [OpenStruct] the configuration object
    # @param prompt_handler [PromptHandler] the prompt handler
    # @param client [AIClientAdapter] the AI client adapter
    def initialize(config, prompt_handler, client)
      @config = config
      @prompt_handler = prompt_handler
      @client = client
      @history_manager = HistoryManager.new(config)
      @ui_presenter = UIPresenter.new(config)
      @directive_processor = DirectiveProcessor.new(config)
      @chat_processor = ChatProcessorService.new(config, client, @ui_presenter, @directive_processor)
      
      # Overwrite the out_file if it exists and append is false
      if @config.out_file && !@config.append && File.exist?(@config.out_file)
        File.open(@config.out_file, 'w') {} # Truncate the file
      end
    end

    # Starts the session, processing the initial prompt and handling user
    # interactions. It manages the flow of prompts, context, and responses.
    def start
      # Get prompt using the prompt_handler which uses PromptManager
      prompt_id = @config.prompt_id
      role_id = @config.role

      # If directly starting in chat mode with empty prompt_id and no role
      if @config.chat && prompt_id.empty? && !role_id
        # Just start a chat with no system prompt
        start_chat
        return
      end

      # Skip prompt validation if starting directly in chat mode with a role
      if @config.chat && role_id && (!prompt_id || prompt_id.empty?)
        # Just start chat with the role
        start_chat_with_role(role_id)
        return
      end

      # Create a prompt object using PromptManager
      prompt = PromptManager::Prompt.get(id: prompt_id) rescue nil

      if prompt.nil?
        puts "Error: Could not find prompt with ID: #{prompt_id}"
        return
      end

      # Handle role if specified
      if role_id
        role_prompt = PromptManager::Prompt.get(id: role_id) rescue nil
        if role_prompt
          prompt.text = "#{role_prompt.text}\n#{prompt.text}"
        else
          puts "Warning: Could not find role with ID: #{role_id}"
        end
      end
      # Extract variables from the prompt using PromptManager
      variables = prompt.keywords

      # Check for variables in the prompt and prompt the user for values
      if variables && !variables.empty?
        variable_values = {}
        # Load variable history
        history = @history_manager.load_variable_history
        prompt_history = history[prompt_id] || {}

        variables.each do |variable|
          # Get history for this variable
          var_history = @history_manager.get_variable_history(prompt_id, variable)

          # Setup Reline history with previous values
          @history_manager.setup_variable_history(var_history)

          # Get default value (most recent entry)
          default = var_history.last

          # Show prompt with default value if available
          puts "\nParameter [#{variable}] ..."
          $stdout.flush

          prompt_text = if default.nil? || default.empty?
                          "> "
                        else
                          "(#{default}) > "
                        end

          value = Reline.readline(prompt_text, true).strip

          # Use default if user just pressed Enter
          value = default if value.empty? && !default.nil?

          # Save value and update history
          variable_values[variable] = value

          # Update history for this variable
          @history_manager.get_variable_history(prompt_id, variable, value)
        end

        # Set parameters on prompt
        prompt.parameters = variable_values
      end

      # Ensure prompt text is processed with parameters
      prompt_text = prompt.to_s

      # Process shell commands, backticks, and environment variables if enabled
      if @config.shell
        prompt_text = prompt_text.gsub(/\$\((.*?)\)/) do
          ShellCommandExecutor.execute_command(Regexp.last_match(1), @config)
        end
        
        prompt_text = prompt_text.gsub(/`([^`]+)`/) do
          ShellCommandExecutor.execute_command(Regexp.last_match(1), @config)
        end
        
        prompt_text = prompt_text.gsub(/\$(\w+)|\$\{(\w+)\}/) { ENV[Regexp.last_match(1) || Regexp.last_match(2)] || "" }
      end

      # Process directives in the prompt - special handling for script content
      # Split the prompt into lines and process each directive line by line
      if prompt_text.include?('//') # Only process if it contains potential directive markers
        lines = prompt_text.split("\n")
        modified_lines = []
        
        lines.each do |line|
          if line.strip.start_with?('//')
            # This is a directive line - process it
            directive_type, directive_args = line.strip[2..-1].split(' ', 2)
            directive_args ||= ''
            
            case directive_type
            when "config", "cfg"
              if directive_args.include?('=')
                key, value = directive_args.split('=', 2).map(&:strip)
                # Convert value to appropriate type
                parsed_value = case value.downcase
                  when 'true' then true
                  when 'false' then false
                  when /^\d+$/ then value.to_i
                  when /^\d+\.\d+$/ then value.to_f
                  else value
                end
                @config[key.to_sym] = parsed_value
                modified_lines << "# #{line} (processed)" # Comment it out but keep it for reference
              else
                modified_lines << line # Keep as is if not a valid config directive
              end
            when "shell", "sh"
              # Execute the shell command and replace the line with its output
              result = ShellCommandExecutor.execute_command(directive_args, @config)
              modified_lines << "# #{line} (processed)" # Comment out the original directive
              modified_lines << ""  # Empty line for readability
              modified_lines << "# Output from: #{directive_args}" # Add comment for clarity
              modified_lines << result # Add the actual output
              modified_lines << ""  # Empty line for readability
            else
              # Unknown directive or one that should be handled differently
              modified_lines << line
            end
          else
            # Not a directive, keep as is
            modified_lines << line
          end
        end
        
        # Replace the prompt_text with the modified version
        prompt_text = modified_lines.join("\n")
      end

      # Process ERB if enabled
      if @config.erb
        prompt_text = ERB.new(prompt_text).result(binding)
      end

      # Process directives in the prompt
      if @directive_processor.directive?(prompt_text)
        directive_result = @directive_processor.process(prompt_text, @history_manager.history)
        prompt_text = directive_result[:result]
        @history_manager.history = directive_result[:modified_history] if directive_result[:modified_history]
      end

      # Add context files if any
      if @config.context_files && !@config.context_files.empty?
        context = @config.context_files.map do |file|
          File.read(file) rescue "Error reading file: #{file}"
        end.join("\n\n")

        prompt_text = "#{prompt_text}\n\nContext:\n#{context}"
      end

      # Determine the type of operation based on the model
      operation_type = @chat_processor.determine_operation_type(@config.model)

      # Process the prompt based on the operation type
      response = @chat_processor.process_prompt(prompt_text, operation_type)

      # Handle output
      @chat_processor.output_response(response)

      # Process next prompt or pipeline if specified
      @chat_processor.process_next_prompts(response, @prompt_handler)

      # Enter chat mode if requested
      start_chat if @config.chat
    end

    # Starts a chat session, handling user input and AI responses in a loop.
    def start_chat
      @ui_presenter.display_chat_header

      # Setup Reline history
      Reline::HISTORY.clear

      loop do
        # Get user input
        prompt = @ui_presenter.ask_question

        # Exit if user types 'exit' or presses Ctrl+D
        break if prompt.nil? || prompt.strip.downcase == 'exit'

        # Append user input to out_file if specified
        if @config.out_file
          File.open(@config.out_file, 'a') do |file|
            file.puts "\nYou: #{prompt}"
          end
        end
        if @directive_processor.directive?(prompt)
          result = @directive_processor.process(prompt, @history_manager.history)
          directive_output = result[:result]
          
          # Update history if it was modified (e.g., by //clear)
          @history_manager.history = result[:modified_history] if result[:modified_history]

          # If there's no output from the directive, prompt for input again
          if directive_output.nil? || directive_output.strip.empty?
            next
          else
            # Special handling for directives that should be excluded from chat context
            if @directive_processor.exclude_from_chat_context?(prompt)
              puts "\n#{directive_output}\n"
              next
            end

            # Add directive output to chat context and continue
            puts "\n#{directive_output}\n"
            prompt = "I executed this directive: #{prompt}\nHere's the output: #{directive_output}\nLet's continue our conversation."
          end
        end

        # Process shell commands and ERB if enabled
        prompt = @chat_processor.process_dynamic_content(prompt)

        # Add to history
        @history_manager.add_to_history('user', prompt)

        # Prepare full conversation context
        conversation = @history_manager.build_conversation_context(prompt, @config.system_prompt)

        # Get response
        operation_type = @chat_processor.determine_operation_type(@config.model)
        @ui_presenter.display_thinking_animation
        response = @chat_processor.process_prompt(conversation, operation_type)

        # Output response with formatting
        @ui_presenter.display_ai_response(response)

        # Add to history
        @history_manager.add_to_history('assistant', response)

        # Speak response if enabled
        @chat_processor.speak(response)

        # Add a separator
        @ui_presenter.display_separator
      end

      @ui_presenter.display_chat_end
    end

    # Start chat with just a role
    # Starts a chat session with a specified role, setting the system prompt
    # from the role and initiating the chat.
    #
    # @param role_id [String] the role ID to use for the chat
    def start_chat_with_role(role_id)
      # Add 'roles/' prefix to role_id if it doesn't already have it
      roles = @config.roles_dir.split('/').last
      role_path = role_id.start_with?(roles+'/') ? role_id : "roles/#{role_id}"

      # Get the role prompt
      role_prompt = PromptManager::Prompt.get(id: role_path) rescue nil

      if role_prompt.nil?
        puts "Error: Could not find role with ID: #{role_id}"
        return
      end

      # Set the system prompt from the role
      @config.system_prompt = role_path

      # Start the chat
      start_chat
    end
  end
end
