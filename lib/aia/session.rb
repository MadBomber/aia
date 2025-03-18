# lib/aia/session.rb
#
# This file manages the session logic for the AIA application.

require 'tty-spinner'
require 'tty-screen'
require 'reline'
require 'prompt_manager'
require 'json'
require 'fileutils'
require 'amazing_print'
require_relative 'directive_processor'

module AIA
  # The Session class manages the interactive session logic for the AIA
  # application. It handles user input, prompt processing, and interaction
  # with the AI client.
  class Session
    KW_HISTORY_MAX = 5 # Maximum number of history entries per keyword
    USER_PROMPT = "Follow up (cntl-D or 'exit' to end) #=> "

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
      @speaker = speak? ? AiClient.new(config.speech_model) : nil
      @history = []
      @variable_history_file = File.join(ENV['HOME'], '.aia', 'variable_history.json')
      @terminal_width = TTY::Screen.width
      @directive_processor = DirectiveProcessor.new(config)
      ensure_history_file_exists
      # Overwrite the out_file if it exists and append is false
      if @config.out_file && !@config.append && File.exist?(@config.out_file)
        File.open(@config.out_file, 'w') {} # Truncate the file
      end
    end

    def speak?
      @config.speak
    end

    def speak(text)
      if speak?
        `#{@config.speak_command} #{@speaker.speak(text).path}`
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
        history = load_variable_history
        prompt_history = history[prompt_id] || {}

        variables.each do |variable|
          # Get history for this variable
          var_history = prompt_history[variable] || []

          # Setup Reline history with previous values
          setup_variable_history(var_history)

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
          unless value.nil? || value.empty?
            # Remove value if it's already in history to avoid duplicates
            var_history.delete(value)

            # Add to end of history (most recent)
            var_history << value

            # Trim history to max size
            var_history.shift if var_history.size > KW_HISTORY_MAX

            # Update history in memory
            prompt_history[variable] = var_history
            history[prompt_id] = prompt_history
          end
        end

        # Save updated history
        save_variable_history(history)

        # Set parameters on prompt
        prompt.parameters = variable_values
      end

      # Ensure prompt text is processed with parameters
      # Remove incorrect parameter substitution
      # prompt_text = prompt.text % prompt.parameters.transform_keys { |key| "[#{key}]" }
      
      # The prompt_manager already handles parameter substitution in the build method,
      # so we should just call prompt.to_s or prompt.prompt to get the text with parameters substituted
      prompt_text = prompt.to_s

      # Process the prompt using our handler (which now properly uses PromptManager directives)
      prompt_text = @prompt_handler.process_prompt(prompt_text)

      # Add context files if any
      if @config.context_files && !@config.context_files.empty?
        context = @config.context_files.map do |file|
          File.read(file) rescue "Error reading file: #{file}"
        end.join("\n\n")

        prompt_text = "#{prompt_text}\n\nContext:\n#{context}"
      end

      # Determine the type of operation based on the model
      operation_type = determine_operation_type(@config.model)

      # Process the prompt based on the operation type
      response = process_prompt(prompt_text, operation_type)

      # Handle output
      output_response(response)

      # Process next prompt or pipeline if specified
      process_next_prompts(response)

      # Enter chat mode if requested
      start_chat if @config.chat
    end

    # Setup Reline history with variable history values
    # Sets up the Reline history with the provided variable history values.
    #
    # @param history_values [Array<String>] the history values to set up
    def setup_variable_history(history_values)
      Reline::HISTORY.clear
      history_values.each do |value|
        Reline::HISTORY.push(value) unless value.nil? || value.empty?
      end
    end

    # Load variable history from JSON file
    # Loads the variable history from a JSON file.
    #
    # @return [Hash] the loaded variable history
    def load_variable_history
      begin
        JSON.parse(File.read(@variable_history_file))
      rescue JSON::ParserError
        {} # Return empty hash if file is invalid
      end
    end

    # Save variable history to JSON file
    # Saves the variable history to a JSON file.
    #
    # @param history [Hash] the variable history to save
    def save_variable_history(history)
      File.write(@variable_history_file, JSON.pretty_generate(history))
    end

    # Processes the given prompt based on the specified operation type.
    #
    # @param prompt [String] the prompt text to process
    # @param operation_type [Symbol] the type of operation (e.g., :text_to_text)
    # @return [String] the response from the AI client
    def process_prompt(prompt, operation_type)
      if @config.verbose
        spinner = TTY::Spinner.new("[:spinner] Processing #{operation_type}...", format: :bouncing_ball,)
        spinner.auto_spin

        response = send_to_client(prompt, operation_type)

        spinner.stop
        response
      else
        send_to_client(prompt, operation_type)
      end
    end

    # Sends the prompt to the AI client based on the operation type.
    #
    # @param prompt [String] the prompt text to send
    # @param operation_type [Symbol] the type of operation (e.g., :text_to_text)
    # @return [String] the response from the AI client
    def send_to_client(prompt, operation_type)
      case operation_type
      when :text_to_text
        @client.chat(prompt)
      when :text_to_image
        @client.chat(prompt) # The adapter will handle this as image generation
      when :image_to_text
        @client.chat(prompt) # The adapter will handle this as vision
      when :text_to_audio
        @client.chat(prompt) # The adapter will handle this as speech
      when :audio_to_text
        # If prompt is a path to an audio file, transcribe it
        if prompt.strip.end_with?('.mp3', '.wav', '.m4a', '.flac') && File.exist?(prompt.strip)
          @client.transcribe(prompt.strip)
        else
          @client.chat(prompt) # Fall back to regular chat
        end
      else
        @client.chat(prompt)
      end
    end

    # Outputs the response from the AI client, handling speaking, logging,
    # and writing to files as configured.
    #
    # @param response [String] the response to output
    def output_response(response)
      speak(response)

      # Only output to STDOUT if we're in chat mode or no output file is specified
      puts response unless !@config.chat && @config.out_file
      
      if @config.out_file
        mode = @config.append ? 'a' : 'w'
        File.open(@config.out_file, mode) do |file|
          file.puts response
        end
      end

      # Log response if configured
      if @config.log_file
        File.open(@config.log_file, 'a') do |f|
          f.puts "=== #{Time.now} ==="
          f.puts "Prompt: #{@config.prompt_id}"
          f.puts "Response: #{response}"
          f.puts "==="
        end
      end
    end

    # Processes the next prompts or pipeline based on the current response
    # and configuration settings.
    #
    # @param response [String] the current response to use as context
    def process_next_prompts(response)
      # Process next prompt if specified
      if @config.next
        next_prompt = PromptManager::Prompt.get(id: @config.next) rescue nil

        if next_prompt
          # Add the previous response as context
          next_prompt_text = @prompt_handler.process_prompt(next_prompt)
          next_prompt_text = "#{next_prompt_text}\n\nContext:\n#{response}"

          operation_type = determine_operation_type(@config.model)
          next_response = process_prompt(next_prompt_text, operation_type)
          output_response(next_response)

          # Update response for potential pipeline
          response = next_response
        else
          puts "Warning: Could not find next prompt with ID: #{@config.next}"
        end
      end

      # Process pipeline if specified
      if @config.pipeline && !@config.pipeline.empty?
        pipeline_response = response

        @config.pipeline.each do |prompt_id|
          pipeline_prompt = PromptManager::Prompt.get(id: prompt_id) rescue nil

          if pipeline_prompt
            # Add the previous response as context
            pipeline_prompt_text = @prompt_handler.process_prompt(pipeline_prompt)
            pipeline_prompt_text = "#{pipeline_prompt_text}\n\nContext:\n#{pipeline_response}"

            operation_type = determine_operation_type(@config.model)
            pipeline_response = process_prompt(pipeline_prompt_text, operation_type)
            output_response(pipeline_response)
          else
            puts "Warning: Could not find pipeline prompt with ID: #{prompt_id}"
          end
        end
      end
    end

    # Starts a chat session, handling user input and AI responses in a loop.
    def start_chat
      display_chat_header

      # Setup Reline history
      Reline::HISTORY.clear

      loop do
        # Get user input
        prompt = ask_question

        # Exit if user types 'exit' or presses Ctrl+D
        break if prompt.nil? || prompt.strip.downcase == 'exit'

        # Append user input to out_file if specified
        if @config.out_file
          File.open(@config.out_file, 'a') do |file|
            file.puts "\nYou: #{prompt}"
          end
        end
        if @directive_processor.directive?(prompt)
          result = @directive_processor.process(prompt, @history)
          directive_output = result[:result]
          
          # Update history if it was modified (e.g., by //clear)
          @history = result[:modified_history] if result[:modified_history]

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
        prompt = process_dynamic_content(prompt)

        # Add to history
        @history << { role: 'user', content: prompt }

        # Prepare full conversation context
        conversation = build_conversation_context(prompt)

        # Get response
        operation_type = determine_operation_type(@config.model)
        display_thinking_animation
        response = process_prompt(conversation, operation_type)

        # Output response with formatting
        display_ai_response(response)

        # Add to history
        @history << { role: 'assistant', content: response }

        # Speak response if enabled
        speak(response)

        # Add a separator
        display_separator
      end

      display_chat_end
    end

    # Ensure the history file directory exists
    # Ensures that the history file directory exists and creates an empty
    # history file if it does not exist.
    def ensure_history_file_exists
      dir = File.dirname(@variable_history_file)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

      # Create empty history file if it doesn't exist
      unless File.exist?(@variable_history_file)
        File.write(@variable_history_file, '{}')
      end
    end

    # Displays the chat session header.
    def display_chat_header
      puts "#{'═' * @terminal_width}\n"
    end

    # Displays a thinking animation while processing.
    def display_thinking_animation
      puts "\n⏳ Processing...\n"
    end

    # Displays the AI response with formatting.
    #
    # @param response [String] the response to display
    def display_ai_response(response)
      puts "\nAI: "
      format_chat_response(response)

      if @config.out_file
        File.open(@config.out_file, 'a') do |file|
          file.puts "\nAI: "
          format_chat_response(response, file)
        end
      end
    end

    # Displays a separator line in the chat session.
    def display_separator
      puts "\n#{'─' * @terminal_width}"
    end

    # Displays the end of the chat session message.
    def display_chat_end
      puts "\nChat session ended."
    end

    # Prompts the user for input and returns the entered text.
    #
    # @return [String, nil] the user input or nil if the session is interrupted
    def ask_question
      puts USER_PROMPT
      $stdout.flush  # Ensure the prompt is displayed immediately
      begin
        input = Reline.readline('', true)
        return nil if input.nil? # Handle Ctrl+D
        Reline::HISTORY << input unless input.strip.empty?
        input
      rescue Interrupt
        puts "\nChat session interrupted."
        return 'exit'
      end
    end

    # Format the chat response with better readability
    # Formats the chat response for better readability, handling code blocks
    # and regular text.
    #
    # @param response [String] the response to format
    def format_chat_response(response, output = $stdout)
      indent = '   '

      # Handle code blocks specially
      in_code_block = false
      language = ''
      code_content = ''

      response.each_line do |line|
        line = line.chomp

        # Check for code block delimiters
        if line.match?(/^```(\w*)$/) && !in_code_block
          in_code_block = true
          language = $1
          output.puts "#{indent}```#{language}"
        elsif line.match?(/^```$/) && in_code_block
          in_code_block = false
          output.puts "#{indent}```"
        elsif in_code_block
          # Print code with special formatting
          output.puts "#{indent}#{line}"
        else
          # Handle regular text
          output.puts "#{indent}#{line}"
        end
      end
    end

    # Processes dynamic content in the text, such as shell commands and ERB,
    # if enabled in the configuration.
    #
    # @param text [String] the text to process
    # @return [String] the processed text
    def process_dynamic_content(text)
      # Process shell commands, backticks, and environment variables if enabled
      if @config.shell
        text = text.gsub(/\$\((.*?)\)/) { `#{Regexp.last_match(1)}`.chomp }
        text = text.gsub(/`([^`]+)`/) { `#{Regexp.last_match(1)}`.chomp }
        text = text.gsub(/`([^`]+)`/) { `#{Regexp.last_match(1)}`.chomp }
        text = text.gsub(/\$(\w+)|\$\{(\w+)\}/) { ENV[Regexp.last_match(1) || Regexp.last_match(2)] || "" }
      end

      # Process ERB if enabled
      if @config.erb
        text = ERB.new(text).result(binding)
      end

      text
    end

    # Builds the conversation context by combining the system prompt, chat
    # history, and the current user prompt.
    #
    # @param current_prompt [String] the current user prompt
    # @return [String] the complete conversation context
    def build_conversation_context(current_prompt)
      # Use the system prompt if available
      system_prompt = ""
      if @config.system_prompt
        system_prompt = PromptManager::Prompt.get(id: @config.system_prompt).to_s rescue ""
      end

      # Prepare the conversation history
      history_text = ""
      if !@history.empty?
        @history.each do |entry|
          history_text += "#{entry[:role].capitalize}: #{entry[:content]}\n\n"
        end
      end

      # Combine system prompt, history, and current prompt
      if !system_prompt.empty?
        "#{system_prompt}\n\n#{history_text}User: #{current_prompt}"
      else
        "#{history_text}User: #{current_prompt}"
      end
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

    private

    # Determines the type of operation to perform based on the model name.
    #
    # @param model [String] the model name
    # @return [Symbol] the operation type (e.g., :text_to_text)
    def determine_operation_type(model)
      model = model.to_s.downcase
      if model.include?('dall') || model.include?('image-generation')
        :text_to_image
      elsif model.include?('vision') || model.include?('image')
        :image_to_text
      elsif model.include?('tts') || model.include?('speech')
        :text_to_audio
      elsif model.include?('whisper') || model.include?('transcription')
        :audio_to_text
      else
        :text_to_text
      end
    end
  end
end
