# frozen_string_literal: true

require 'tty-spinner'
require 'reline'

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
      
      # Add context files if any
      if @config.context_files && !@config.context_files.empty?
        context = @config.context_files.map do |file|
          File.read(file) rescue "Error reading file: #{file}"
        end.join("\n\n")
        
        prompt_text = "#{prompt_text}\n\nContext:\n#{context}"
      end
      
      # Send prompt to AI and get response
      response = send_prompt(prompt_text)
      
      # Handle output
      output_response(response)
      
      # Process next prompt or pipeline if specified
      process_next_prompts(response)
      
      # Enter chat mode if requested
      start_chat if @config.chat
    end

    def send_prompt(prompt)
      if @config.verbose
        spinner = TTY::Spinner.new("[:spinner] Processing prompt...", format: :dots)
        spinner.auto_spin
        
        response = @client.chat(prompt)
        
        spinner.stop
        response
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
        
        next_response = send_prompt(next_prompt_text)
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
          
          pipeline_response = send_prompt(pipeline_prompt_text)
          output_response(pipeline_response)
        end
      end
    end

    def start_chat
      loop do
        print "\nFollow-up (blank to exit): "
        follow_up = Reline.readline("", true)
        
        break if follow_up.empty?
        
        # Process follow-up for directives, shell, erb
        processed_follow_up = @prompt_handler.process_text(follow_up)
        
        response = send_prompt(processed_follow_up)
        puts response
        
        # Speak response if configured
        @client.speak(response) if @config.speak
        
        # Add to history
        @history << { prompt: processed_follow_up, response: response }
      end
    end
  end
end
