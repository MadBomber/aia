# lib/aia/directive_processor.rb

# require 'active_support/all'
require 'faraday'
require 'word_wrapper'
require_relative 'directives/registry'

module AIA
  class DirectiveProcessor
    using Refinements

    EXCLUDED_METHODS = %w[run initialize private?]

    def initialize
      @prefix_size = PromptManager::Prompt::DIRECTIVE_SIGNAL.size
      @included_files = []
      Directives::WebAndFile.included_files = @included_files
    end


    def directive?(string)
      Directives::Registry.directive?(string)
    end


    def process(string, context_manager)
      return string unless directive?(string)

      content = if string.is_a?(RubyLLM::Message)
                  begin
                    string.content
                  rescue StandardError
                    string.to_s
                  end
                else
                  string.to_s
                end

      key = content.strip
      sans_prefix = key[@prefix_size..]
      args = sans_prefix.split(' ')
      method_name = args.shift.downcase

      Directives::Registry.process(method_name, args, context_manager)
    end


    def run(directives)
      return {} if directives.nil? || directives.empty?

      directives.each do |key, _|
        sans_prefix = key[@prefix_size..]
        args = sans_prefix.split(' ')
        method_name = args.shift.downcase

        # Use the new module-based directive system
        # Pass nil as context_manager since it's not available at the prompt processing level
        directives[key] = Directives::Registry.process(method_name, args, nil)
      end

      directives
    end

    private

    def private?(method_name)
      !respond_to?(method_name) && respond_to?(method_name, true)
    end

    ################
    ## Directives ##
    ################

    # All directive implementations are now in separate modules
    # and are accessed through the Registry

    # Keep backward compatibility by delegating to Registry
    def method_missing(method_name, *args, &block)
      if Directives::Registry.respond_to?(method_name, true)
        Directives::Registry.send(method_name, *args, &block)
      else
        super
      end
    end


    def respond_to_missing?(method_name, include_private = false)
      Directives::Registry.respond_to?(method_name, include_private) || super
    end
  end
end
