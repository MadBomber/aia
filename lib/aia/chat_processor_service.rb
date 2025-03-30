# lib/aia/chat_processor_service.rb
#
# This file contains the ChatProcessorService class for managing conversation processing logic.
# The ChatProcessorService class is responsible for processing chat prompts,
# handling AI client interactions, and managing the flow of the conversation.

require_relative 'shell_command_executor'

module AIA
  # The ChatProcessorService class is responsible for processing chat prompts,
  # handling AI client interactions, and managing the flow of the conversation.
  class ChatProcessorService
    # Initializes a new ChatProcessorService with the given configuration and client.
    #
    # @param config [OpenStruct] the configuration object
    # @param client [AIClientAdapter] the AI client adapter
    # @param ui_presenter [UIPresenter] the UI presenter for displaying output
    # @param directive_processor [DirectiveProcessor] the directive processor for handling chat directives
    def initialize(config, client, ui_presenter, directive_processor = nil)
      @config = config
      @client = client
      @ui_presenter = ui_presenter
      @speaker = speak? ? AiClient.new(config.speech_model) : nil
      @directive_processor = directive_processor
    end

    # Checks if speech is enabled in the configuration.
    #
    # @return [Boolean] true if speech is enabled, false otherwise
    def speak?
      @config.speak
    end

    # Speaks the given text using the configured speech model.
    #
    # @param text [String] the text to speak
    def speak(text)
      if speak?
        # Initialize speaker on-demand if it doesn't exist but speak is enabled
        @speaker ||= AiClient.new(@config.speech_model) if @config.speech_model
        
        # Only proceed if speaker is properly initialized
        if @speaker
          `#{@config.speak_command} #{@speaker.speak(text).path}`
        else
          puts "Warning: Unable to speak. Speech model not configured properly."
        end
      end
    end

    # Processes the given prompt based on the specified operation type.
    #
    # @param prompt [String] the prompt text to process
    # @param operation_type [Symbol] the type of operation (e.g., :text_to_text)
    # @return [String] the response from the AI client
    def process_prompt(prompt, operation_type)
      @ui_presenter.with_spinner("Processing", operation_type) do
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
    # @param prompt_handler [PromptHandler] the prompt handler to use
    def process_next_prompts(response, prompt_handler)
      # Process directives in the response
      if @directive_processor.directive?(response)
        directive_result = @directive_processor.process(response, @history_manager.history)
        response = directive_result[:result]
        @history_manager.history = directive_result[:modified_history] if directive_result[:modified_history]
      end
    end

    # Processes dynamic content in text, such as shell commands and environment variables.
    #
    # @param text [String] the text to process
    # @return [String] the processed text
    def process_dynamic_content(text)
      # Process shell commands, backticks, and environment variables if enabled
      if @config.shell
        text = text.gsub(/\$\((.*?)\)/) do
          ShellCommandExecutor.execute_command(Regexp.last_match(1), @config)
        end
        
        text = text.gsub(/`([^`]+)`/) do
          ShellCommandExecutor.execute_command(Regexp.last_match(1), @config)
        end
        
        text = text.gsub(/\$(\w+)|\$\{(\w+)\}/) { ENV[Regexp.last_match(1) || Regexp.last_match(2)] || "" }
      end

      # Process ERB if enabled
      if @config.erb
        begin
          text = ERB.new(text).result(binding)
        rescue => e
          text = "Error processing ERB: #{e.message}"
        end
      end

      text
    end

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
      elsif model.include?('whisper') || model.include?('audio')
        :audio_to_text
      elsif model.include?('speech') || model.include?('tts')
        :text_to_audio
      else
        :text_to_text
      end
    end
  end
end
