# lib/aia/patches/ruby_llm_tool_param_compat.rb
#
# ruby_llm 1.x tools declare arguments with `param ... desc:`; ruby_llm 2.0
# renamed the DSL to `parameter ... description:`. AIA's tool classes are
# written in the 2.0 style. On a 1.x runtime this shim translates the 2.0
# declaration back onto the 1.x `param` DSL so the same tool classes load on
# both lines. Retire together with ruby_llm 1.x support.

module AIA
  module RubyLLMToolParamCompat
    def parameter(name, **options)
      options[:desc] = options.delete(:description) if options.key?(:description)
      param(name, **options)
    end
  end
end

RubyLLM::Tool.extend(AIA::RubyLLMToolParamCompat) unless RubyLLM::Tool.respond_to?(:parameter)
