# lib/aia/patches/ruby_llm_tool_error.rb
#
# Two ruby_llm hardening patches:
#
#   1. RubyLLM::Chat#execute_tool — rescue any exception raised during tool
#      execution and return it as an error hash instead of raising. Without
#      this, an exception inside a tool skips the add_message call in
#      handle_tool_calls, leaving an orphaned tool_call in the conversation
#      history with no matching tool_result. Most LLMs reject that state on the
#      next request, killing the session. ruby_llm's own execute_tool does NOT
#      rescue tool exceptions, so this is still required as of 1.16.
#
#   2. RubyLLM::Provider#complete — normalize OpenAI o-series / gpt-5 params
#      (max_tokens -> max_completion_tokens) before the request.
#
# Both patches are applied via #prepend + super so they preserve ruby_llm's own
# method body (including its instrumentation) and survive internal changes to
# that body. They are guarded against drift: if a future ruby_llm renames or
# removes the target method, the patch is skipped with a loud warning rather
# than silently installing dead code or breaking every request.

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

  # Prepended onto RubyLLM::Provider. Uses a pass-through (*args, **kwargs)
  # signature so any kwargs ruby_llm adds in future are forwarded to super
  # unchanged; we only rewrite params before delegating.
  module RubyLLMOpenAIParameters
    def complete(*, **kwargs, &)
      kwargs[:params] = AIA::OpenAIParameterNormalizer.normalize(
        kwargs[:params] || {}, kwargs[:model], self
      )
      super
    end
  end

  # Prepended onto RubyLLM::Chat. Calls super (ruby_llm's own instrumented
  # execute_tool) and only adds exception rescue, so tool-call instrumentation
  # is preserved.
  module RubyLLMChatToolError
    private

    def execute_tool(tool_call)
      super
    rescue SignalException, SystemExit
      raise
    rescue Exception => e # rubocop:disable Lint/RescueException
      RubyLLM.logger.warn { "Tool #{tool_call.name} raised #{e.class}: #{e.message}" }
      { error: "#{e.class}: #{e.message}" }
    end
  end
end

# --- Apply patches, guarded against ruby_llm API drift ---

if RubyLLM::Provider.private_method_defined?(:complete) ||
   RubyLLM::Provider.method_defined?(:complete)
  RubyLLM::Provider.prepend(AIA::RubyLLMOpenAIParameters)
else
  $stderr.puts "WARNING: [AIA] ruby_llm patch skipped: RubyLLM::Provider#complete " \
               "not found (ruby_llm #{RubyLLM::VERSION}). OpenAI param normalization is off."
end

if RubyLLM::Chat.private_method_defined?(:execute_tool) ||
   RubyLLM::Chat.method_defined?(:execute_tool)
  RubyLLM::Chat.prepend(AIA::RubyLLMChatToolError)
else
  $stderr.puts "WARNING: [AIA] ruby_llm patch skipped: RubyLLM::Chat#execute_tool " \
               "not found (ruby_llm #{RubyLLM::VERSION}). Tool-exception handling is degraded."
end
