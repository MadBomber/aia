# ~/examples/directives/ask.rb
# Desc: An example of how to extend the AIA directives
# Usage: aia <options> --require path/to/ask.rb
#
# A directive is just a private method of the AIA::DirectiveProcessor class.  its
# definition is preceeded by the `desc` method which has a single String parameter
# that is a description of the directive.  This discription is shown with the
# directive's name in the --chat mode with the //help directive is used.

module AIA
  class DirectiveProcessor
    private
    desc "A meta-prompt to LLM making its response available as part of the primary prompt"
    # args is an Array of Strings
    # context_manager is an optional parameter TBD
    def ask(args, context_manager=nil)
      meta_prompt = args.empty? ? "What is meta-prompting?" : args.join(' ')
      AIA.config.client.chat(meta_prompt)
    end
  end
end
