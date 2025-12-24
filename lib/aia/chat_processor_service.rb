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
      logger.debug("Result received", result_class: result.class.name)
      logger.debug("Result details", inspect: result.inspect[0..500])

      # Preserve token information if available for metrics
      if result.is_a?(String)
        logger.debug("Processing result", type: "String")
        { content: result, metrics: nil }
      elsif result.respond_to?(:multi_model?) && result.multi_model?
        logger.debug("Processing result", type: "multi-model response")
        # Handle multi-model response with metrics
        {
          content: result.content,
          metrics: nil,  # Individual model metrics handled separately
          multi_metrics: result.metrics_list
        }
      elsif result.respond_to?(:content)
        logger.debug("Processing result", type: "standard response with content method")
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
        logger.debug("Processing result", type: "fallback (unexpected type)")
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
        logger.debug("Sending per-model conversations to client")
        result = AIA.client.chat(conversation_or_conversations)
      else
        # Single conversation for single model
        logger.debug("Sending conversation to client", conversation: conversation_or_conversations.inspect[0..500])
        result = AIA.client.chat(conversation_or_conversations)
      end

      logger.debug("Client returned", result_class: result.class.name, result: result.inspect[0..500])
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
