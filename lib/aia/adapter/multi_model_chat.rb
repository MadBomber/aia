# lib/aia/adapter/multi_model_chat.rb
# frozen_string_literal: true

require 'async'

module AIA
  module Adapter
    module MultiModelChat
      # Helper class to carry multi-model response with metrics
      class MultiModelResponse
        attr_reader :content, :metrics_list

        def initialize(content, metrics_list)
          @content = content
          @metrics_list = metrics_list
        end

        def multi_model?
          true
        end
      end

      # Prepend role content to prompt for a specific model (ADR-005)
      def prepend_model_role(prompt, internal_id)
        # Get model spec to find role
        spec = get_model_spec(internal_id)
        return prompt unless spec && spec[:role]

        # Get role content using PromptHandler
        prompt_handler = AIA::PromptHandler.new
        role_content = prompt_handler.load_role_for_model(spec, AIA.config.prompts.role)

        return prompt unless role_content

        # Prepend role to prompt based on prompt type
        if prompt.is_a?(String)
          "#{role_content}\n\n#{prompt}"
        elsif prompt.is_a?(Array)
          prepend_role_to_conversation(prompt, role_content)
        else
          prompt
        end
      end

      def prepend_role_to_conversation(conversation, role_content)
        # Find the first user message and prepend role
        modified = conversation.dup
        first_user_index = modified.find_index { |msg| msg[:role] == "user" || msg["role"] == "user" }

        if first_user_index
          msg = modified[first_user_index].dup
          content_key = msg.key?(:content) ? :content : "content"

          msg[content_key] = "#{role_content}\n\n#{msg[content_key]}"
          modified[first_user_index] = msg
        end

        modified
      end

      def multi_model_chat(prompt_or_contexts)
        results = {}

        # Check if we're receiving per-model contexts (Hash) or shared prompt (String/Array) - ADR-002 revised
        per_model_contexts = prompt_or_contexts.is_a?(Hash) &&
                             prompt_or_contexts.keys.all? { |k| @models.include?(k) }

        Async do |task|
          @models.each do |internal_id|
            task.async do
              begin
                # Use model-specific context if available, otherwise shared prompt
                prompt = if per_model_contexts
                           prompt_or_contexts[internal_id]
                         else
                           prompt_or_contexts
                         end

                # Add per-model role if specified (ADR-005)
                prompt = prepend_model_role(prompt, internal_id)

                result = single_model_chat(prompt, internal_id)
                results[internal_id] = result
              rescue StandardError => e
                results[internal_id] = "Error with #{internal_id}: #{e.message}"
              end
            end
          end
        end

        # Format and return results from all models
        format_multi_model_results(results)
      end

      def format_multi_model_results(results)
        if should_use_consensus_mode?
          generate_consensus_response(results)
        else
          format_individual_responses(results)
        end
      end

      def should_use_consensus_mode?
        AIA.config.flags.consensus == true
      end

      def generate_consensus_response(results)
        primary_model = @models.first
        primary_chat = @chats[primary_model]

        consensus_prompt = build_consensus_prompt(results)

        begin
          consensus_result = primary_chat.ask(consensus_prompt).content
          "from: #{primary_model}\n#{consensus_result}"
        rescue StandardError => e
          "Error generating consensus: #{e.message}\n\n" + format_individual_responses(results)
        end
      end

      def build_consensus_prompt(results)
        prompt_parts = []
        prompt_parts << "You are tasked with creating a consensus response based on multiple AI model responses to the same query."
        prompt_parts << "Please analyze the following responses and provide a unified, comprehensive answer that:"
        prompt_parts << "- Incorporates the best insights from all models"
        prompt_parts << "- Resolves any contradictions with clear reasoning"
        prompt_parts << "- Provides additional context or clarification when helpful"
        prompt_parts << "- Maintains accuracy and avoids speculation"
        prompt_parts << ""
        prompt_parts << "Model responses:"
        prompt_parts << ""

        results.each do |model_name, result|
          content = if result.respond_to?(:content)
                      result.content
                    else
                      result.to_s
                    end
          next if content.start_with?("Error with")
          prompt_parts << "#{model_name}:"
          prompt_parts << content
          prompt_parts << ""
        end

        prompt_parts << "Please provide your consensus response:"
        prompt_parts.join("\n")
      end

      def format_individual_responses(results)
        has_metrics = results.values.any? { |r| r.respond_to?(:input_tokens) && r.respond_to?(:output_tokens) }

        if has_metrics
          format_multi_model_with_metrics(results)
        else
          output = []
          results.each do |internal_id, result|
            spec = get_model_spec(internal_id)
            display_name = format_model_display_name(spec)

            output << "from: #{display_name}"
            content = if result.respond_to?(:content)
                        result.content
                      else
                        result.to_s
                      end
            output << content
            output << "" # Add blank line between results
          end
          output.join("\n")
        end
      end

      # Format display name with instance number and role (ADR-005)
      def format_model_display_name(spec)
        return spec unless spec.is_a?(Hash)

        model_name = spec[:model]
        instance = spec[:instance]
        role = spec[:role]

        display = if instance > 1
                    "#{model_name} ##{instance}"
                  else
                    model_name
                  end

        display += " (#{role})" if role

        display
      end

      def format_multi_model_with_metrics(results)
        formatted_content = []
        metrics_data = []

        results.each do |internal_id, result|
          spec = get_model_spec(internal_id)
          display_name = format_model_display_name(spec)

          formatted_content << "from: #{display_name}"
          content = result.respond_to?(:content) ? result.content : result.to_s
          formatted_content << content
          formatted_content << ""

          actual_model = spec ? spec[:model] : internal_id
          metrics_data << {
            model_id: actual_model,
            display_name: display_name,
            input_tokens: result.respond_to?(:input_tokens) ? result.input_tokens : nil,
            output_tokens: result.respond_to?(:output_tokens) ? result.output_tokens : nil
          }
        end

        MultiModelResponse.new(formatted_content.join("\n"), metrics_data)
      end
    end
  end
end
