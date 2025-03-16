# frozen_string_literal: true

require 'tty-spinner'
require 'tty-screen'
require 'reline'
require 'prompt_manager'
require 'json'
require 'fileutils'

module AIA
  class Session
    KW_HISTORY_MAX = 5 # Maximum number of history entries per keyword
    USER_PROMPT = "Follow up (cntl-D or 'exit' to end) #=> "
    
    def initialize(config, prompt_handler, client)
      @config = config
      @prompt_handler = prompt_handler
      @client = client
      @history = []
      @variable_history_file = File.join(ENV['HOME'], '.aia', 'variable_history.json')
      @terminal_width = TTY::Screen.width
      ensure_history_file_exists
    end

    def start
      # Get prompt using the prompt_handler which uses PromptManager
      prompt_id = @config.prompt_id
      role_id = @config.role
      
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
      
      # Process the prompt using our handler (which now properly uses PromptManager directives)
      prompt_text = @prompt_handler.process_prompt(prompt)
      
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
    def setup_variable_history(history_values)
      Reline::HISTORY.clear
      history_values.each do |value|
        Reline::HISTORY.push(value) unless value.nil? || value.empty?
      end
    end

    # Ensure the history file directory exists
    def ensure_history_file_exists
      dir = File.dirname(@variable_history_file)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      
      # Create empty history file if it doesn't exist
      unless File.exist?(@variable_history_file)
        File.write(@variable_history_file, '{}')
      end
    end

    # Load variable history from JSON file
    def load_variable_history
      begin
        JSON.parse(File.read(@variable_history_file))
      rescue JSON::ParserError
        {} # Return empty hash if file is invalid
      end
    end

    # Save variable history to JSON file
    def save_variable_history(history)
      File.write(@variable_history_file, JSON.pretty_generate(history))
    end

    def process_prompt(prompt, operation_type)
      if @config.verbose
        spinner = TTY::Spinner.new("[:spinner] Processing #{operation_type}...", format: :dots)
        spinner.auto_spin
        
        response = send_to_client(prompt, operation_type)
        
        spinner.stop
        response
      else
        send_to_client(prompt, operation_type)
      end
    end
    
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

    def output_response(response)
      if @config.speak
        @client.speak(response)
      end
      
      if @config.out_file
        File.write(@config.out_file, response)
      else
        puts response
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
    
    def start_chat
      display_chat_header
      
      # Setup Reline history
      Reline::HISTORY.clear
      
      loop do
        # Get user input
        prompt = ask_question
        
        # Exit if user types 'exit' or presses Ctrl+D
        break if prompt.nil? || prompt.strip.downcase == 'exit'
        
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
        @client.speak(response) if @config.speak
        
        # Add a separator
        display_separator
      end
      
      display_chat_end
    end
    
    def display_chat_header
      puts "#{'═' * @terminal_width}\n"
    end
        
    def display_thinking_animation
      puts "\n⏳ Processing...\n"
    end
    
    def display_ai_response(response)
      puts "AI: "
      format_chat_response(response)
    end
    
    def display_separator
      puts "\n#{'─' * @terminal_width}"
    end
    
    def display_chat_end
      puts "\nChat session ended."
    end
    
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
    def format_chat_response(response)
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
          puts "#{indent}```#{language}" 
        elsif line.match?(/^```$/) && in_code_block
          in_code_block = false
          puts "#{indent}```"
        elsif in_code_block
          # Print code with special formatting
          puts "#{indent}#{line}"
        else
          # Handle regular text
          puts "#{indent}#{line}"
        end
      end
    end
    
    def process_dynamic_content(text)
      # Process shell commands if enabled
      if @config.shell
        text = text.gsub(/\$\((.*?)\)/) { `#{Regexp.last_match(1)}`.chomp }
      end
      
      # Process ERB if enabled
      if @config.erb
        text = ERB.new(text).result(binding)
      end
      
      text
    end
    
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
    
    private
    
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
