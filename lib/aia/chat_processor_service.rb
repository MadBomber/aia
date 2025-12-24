# lib/aia/chat_processor_service.rb

module AIA
  class ChatProcessorService
    def initialize(ui_presenter, directive_processor = nil)
      @ui_presenter = ui_presenter
      @speaker = AIA.speak? ? AiClient.new(AIA.config.audio.speech_model) : nil
      @directive_processor = directive_processor
    end


    def speak(text)
      return unless AIA.speak?

      @speaker ||= AiClient.new(AIA.config.audio.speech_model) if AIA.config.audio.speech_model

      if @speaker
        `#{AIA.config.audio.speak_command} #{@speaker.speak(text).path}`
      else
        puts "Warning: Unable to speak. Speech model not configured properly."
      end
    end


    def process_prompt(prompt)
      result = nil
      @ui_presenter.with_spinner("Processing", determine_operation_type) do
        result = send_to_client(prompt)
      end

      # Debug output to understand what we're receiving
      puts "[DEBUG ChatProcessor] Result class: #{result.class}" if AIA.config.flags.debug
      puts "[DEBUG ChatProcessor] Result inspect: #{result.inspect[0..500]}..." if AIA.config.flags.debug

      # Preserve token information if available for metrics
      if result.is_a?(String)
        puts "[DEBUG ChatProcessor] Processing as String" if AIA.config.flags.debug
        { content: result, metrics: nil }
      elsif result.respond_to?(:multi_model?) && result.multi_model?
        puts "[DEBUG ChatProcessor] Processing as multi-model response" if AIA.config.flags.debug
        # Handle multi-model response with metrics
        {
          content: result.content,
          metrics: nil,  # Individual model metrics handled separately
          multi_metrics: result.metrics_list
        }
      elsif result.respond_to?(:content)
        puts "[DEBUG ChatProcessor] Processing as standard response with content method" if AIA.config.flags.debug
        # Standard response object with content method
        {
          content: result.content,
          metrics: {
            input_tokens: result.respond_to?(:input_tokens) ? result.input_tokens : nil,
            output_tokens: result.respond_to?(:output_tokens) ? result.output_tokens : nil,
            model_id: result.respond_to?(:model_id) ? result.model_id : nil
          }
        }
      else
        puts "[DEBUG ChatProcessor] Processing as fallback (unexpected type)" if AIA.config.flags.debug
        # Fallback for unexpected response types
        { content: result.to_s, metrics: nil }
      end
    end


    # conversation is an Array of Hashes (single model) or Hash of Arrays (multi-model per-model contexts)
    # Each entry is an interchange with the LLM.
    def send_to_client(conversation_or_conversations)
      maybe_change_model

      # Handle per-model conversations (Hash) or single conversation (Array) - ADR-002 revised
      if conversation_or_conversations.is_a?(Hash)
        # Multi-model with per-model contexts: pass Hash directly to adapter
        puts "[DEBUG ChatProcessor] Sending per-model conversations to client" if AIA.config.flags.debug
        result = AIA.client.chat(conversation_or_conversations)
      else
        # Single conversation for single model
        puts "[DEBUG ChatProcessor] Sending conversation to client: #{conversation_or_conversations.inspect[0..500]}..." if AIA.config.flags.debug
        result = AIA.client.chat(conversation_or_conversations)
      end

      puts "[DEBUG ChatProcessor] Client returned: #{result.class} - #{result.inspect[0..500]}..." if AIA.config.flags.debug
      result
    end


    def maybe_change_model
      # With multiple models, we don't need to change the model in the same way
      # The RubyLLMAdapter now handles multiple models internally
      # This method is kept for backward compatibility but may not be needed
      models = AIA.config.models
      return if models.is_a?(Array) && models.size > 1

      return unless AIA.client.respond_to?(:model) && AIA.client.model.respond_to?(:id)
      client_model = AIA.client.model.id

      # Get the first model name for comparison
      first_model = models.first
      model_name = first_model.respond_to?(:name) ? first_model.name : first_model.to_s

      unless model_name.downcase.include?(client_model.downcase)
        AIA.client = AIA.client.class.new
      end
    end


    def output_response(response)
      speak(response)

      out_file = AIA.config.output.file

      # Output to STDOUT or file based on out_file configuration
      if out_file.nil? || 'STDOUT' == out_file.upcase
        print "\nAI:\n  "
        puts response
      else
        mode = AIA.append? ? 'a' : 'w'
        File.open(out_file, mode) do |file|
          file.puts "\nAI: "
          # Handle multi-line responses by adding proper indentation
          response_lines = response.to_s.split("\n")
          response_lines.each do |line|
            file.puts "  #{line}"
          end
        end
      end

      history_file = AIA.config.output.history_file
      if history_file
        File.open(history_file, 'a') do |f|
          f.puts "=== #{Time.now} ==="
          f.puts "Prompt: #{AIA.config.prompt_id}"
          f.puts "Response: #{response}"
          f.puts "==="
        end
      end
    end


    def process_next_prompts(response, prompt_handler)
      if @directive_processor.directive?(response)
        directive_result = @directive_processor.process(response, @history_manager.history)
        response = directive_result[:result]
        @history_manager.history = directive_result[:modified_history] if directive_result[:modified_history]
      end
    end


    def determine_operation_type
      # With multiple models, determine operation type from the first model
      # or provide a generic description
      models = AIA.config.models
      if models.is_a?(Array) && models.size > 1
        "MULTI-MODEL PROCESSING"
      else
        mode = AIA.client.model.modalities
        mode.input.join(',') + " TO " + mode.output.join(',')
      end
    end
  end
end
