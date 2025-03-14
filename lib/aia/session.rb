# frozen_string_literal: true

require 'tty-spinner'
require 'reline'
require 'prompt_manager'

module AIA
  class Session
    def initialize(config, prompt_handler, client)
      @config = config
      @prompt_handler = prompt_handler
      @client = client
      @history = []
    end

    def start
      # Get initial prompt
      prompt_text = @prompt_handler.get_prompt(@config.prompt_id, @config.role)
      
      # Extract variables from the prompt using PromptManager
      prompt = PromptManager::Prompt.new(id: @config.prompt_id, context: [])
      variables = prompt.keywords

      # Check for variables in the prompt and prompt the user for values
      if variables && !variables.empty?
        variable_values = {}
        variables.each do |variable|
          print "Enter value for [#{variable}]: "
          variable_values[variable] = Reline.readline('', true).strip
        end
        prompt.parameters = variable_values
        prompt_text = prompt.build
      end
      
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
        next_prompt_handler = PromptHandler.new(@config)
        next_prompt_text = next_prompt_handler.get_prompt(@config.next)
        next_prompt_text = "#{next_prompt_text}\n\nContext:\n#{response}"
        
        operation_type = determine_operation_type(@config.model)
        next_response = process_prompt(next_prompt_text, operation_type)
        output_response(next_response)
        
        # Update response for potential pipeline
        response = next_response
      end
      
      # Process pipeline if specified
      if @config.pipeline && !@config.pipeline.empty?
        pipeline_response = response
        
        @config.pipeline.each do |prompt_id|
          pipeline_handler = PromptHandler.new(@config)
          pipeline_prompt_text = pipeline_handler.get_prompt(prompt_id)
          pipeline_prompt_text = "#{pipeline_prompt_text}\n\nContext:\n#{pipeline_response}"
          
          operation_type = determine_operation_type(@config.model)
          pipeline_response = process_prompt(pipeline_prompt_text, operation_type)
          output_response(pipeline_response)
        end
      end
    end
    
    def start_chat
      puts "\nChat mode enabled. Type 'exit' or press Ctrl+D to end the chat.\n"
      
      # Setup Reline history
      Reline::HISTORY.clear
      
      loop do
        # Get user input
        prompt = ask_question("You: ")
        
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
        response = process_prompt(conversation, operation_type)
        
        # Output response
        puts "AI: #{response}\n"
        
        # Add to history
        @history << { role: 'assistant', content: response }
        
        # Speak response if enabled
        @client.speak(response) if @config.speak
      end
      
      puts "\nChat session ended."
    end
    
    def ask_question(prompt)
      print prompt
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
      # For simple prompts, just return the current prompt
      return current_prompt if @history.empty?
      
      # For conversation history, format it appropriately
      context = "Conversation history:\n"
      
      @history.each do |message|
        context += "#{message[:role].capitalize}: #{message[:content]}\n"
      end
      
      context += "\nCurrent prompt: #{current_prompt}"
      context
    end
    
    def determine_operation_type(model)
      model = model.downcase
      case model
      when /vision/, /image/
        :image_to_text
      when /dall-e/, /image-generation/
        :text_to_image
      when /tts/, /speech/
        :text_to_audio
      when /whisper/, /transcription/
        :audio_to_text
      else
        :text_to_text
      end
    end
  end
end
