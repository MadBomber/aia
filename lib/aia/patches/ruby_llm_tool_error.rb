# lib/aia/patches/ruby_llm_tool_error.rb
#
# Patches RubyLLM::Chat#execute_tool to rescue any exception raised during
# tool execution and return it as an error hash instead of raising.
#
# Without this patch, an exception inside a tool skips the `add_message`
# call in handle_tool_calls, leaving an orphaned tool_call in the
# conversation history with no matching tool_result. Most LLMs reject
# that state on the next request, killing the session.

module AIA
  class OpenAIParameterNormalizer
    class << self
      def normalize(params, model, provider)
        normalized = params.dup
        return normalized unless uses_completion_tokens_param?(model, provider)
        return normalized unless normalized.key?(:max_tokens)

        max_tokens = normalized.delete(:max_tokens)
        normalized[:max_completion_tokens] ||= max_tokens
        normalized
      end

      private
        def uses_completion_tokens_param?(model, provider)
          provider_slug(provider) == 'openai' && model_id(model).match?(/\A(o\d|gpt-5)/i)
        end

        def provider_slug(provider)
          provider.respond_to?(:slug) ? provider.slug.to_s : nil
        end

        def model_id(model)
          model.respond_to?(:id) ? model.id.to_s : model.to_s
        end
    end
  end

  module RubyLLMOpenAIParameters
    def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, thinking: nil,
                 tool_prefs: nil, &)
      normalized_params = AIA::OpenAIParameterNormalizer.normalize(params, model, self)

      super(
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        params: normalized_params,
        headers: headers,
        schema: schema,
        thinking: thinking,
        tool_prefs: tool_prefs,
        &
      )
    end
  end
end

RubyLLM::Provider.prepend(AIA::RubyLLMOpenAIParameters)

module RubyLLM
  class Chat
    private

    def execute_tool(tool_call)
      tool = tools[tool_call.name.to_sym]
      if tool.nil?
        return {
          error: "Model tried to call unavailable tool `#{tool_call.name}`. " \
                 "Available tools: #{tools.keys.to_json}."
        }
      end

      begin
        tool.call(tool_call.arguments)
      rescue Interrupt, SignalException, SystemExit
        raise
      rescue Exception => e
        RubyLLM.logger.warn { "Tool #{tool_call.name} raised #{e.class}: #{e.message}" }
        { error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
