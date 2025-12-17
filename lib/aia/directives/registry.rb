# lib/aia/directives/registry.rb

require_relative 'web_and_file'
require_relative 'utility'
require_relative 'configuration'
require_relative 'execution'
require_relative 'models'
require_relative 'checkpoint'

module AIA
  module Directives
    module Registry
      EXCLUDED_METHODS = %w[ run initialize private? ]

      class << self
        def descriptions
          @descriptions ||= {}
        end

        def aliases
          @aliases ||= {}
        end

        def desc(description, method_name = nil)
          @last_description = description
          descriptions[method_name.to_s] = description if method_name
          nil
        end

        def method_added(method_name)
          if @last_description
            descriptions[method_name.to_s] = @last_description
            @last_description = nil
          end
          super if defined?(super)
        end

        def build_aliases(private_methods)
          private_methods.each do |method_name|
            method = instance_method(method_name)

            aliases[method_name] = []

            private_methods.each do |other_method_name|
              next if method_name == other_method_name

              other_method = instance_method(other_method_name)

              if method == other_method
                aliases[method_name] << other_method_name
              end
            end
          end
        end

        def register_directive_module(mod)
          @directive_modules ||= []
          @directive_modules << mod
        end

        def process(directive_name, args, context_manager)
          if EXCLUDED_METHODS.include?(directive_name)
            return "Error: #{directive_name} is not a valid directive"
          end
          
          # Check all registered directive modules
          @directive_modules ||= []
          @directive_modules.each do |mod|
            if mod.respond_to?(directive_name)
              return mod.send(directive_name, args, context_manager)
            end
          end
          
          return "Error: Unknown directive '#{directive_name}'"
        end

        def run(directives)
          return {} if directives.nil? || directives.empty?

          directives.each do |key, _|
            sans_prefix = key[prefix_size..]
            args = sans_prefix.split(' ')
            method_name = args.shift.downcase

            if EXCLUDED_METHODS.include?(method_name)
              directives[key] = "Error: #{method_name} is not a valid directive: #{key}"
              next
            elsif respond_to?(method_name, true)
              directives[key] = send(method_name, args)
            else
              directives[key] = "Error: Unknown directive '#{key}'"
            end
          end

          directives
        end

        def prefix_size
          PromptManager::Prompt::DIRECTIVE_SIGNAL.size
        end

        def directive?(string)
          content = if string.is_a?(RubyLLM::Message)
                     string.content rescue string.to_s
                   else
                     string.to_s
                   end

          content.strip.start_with?(PromptManager::Prompt::DIRECTIVE_SIGNAL)
        end
      end

      # Register all directive modules
      register_directive_module(WebAndFile)
      register_directive_module(Utility)
      register_directive_module(Configuration)
      register_directive_module(Execution)
      register_directive_module(Models)
      register_directive_module(Checkpoint)
    end
  end
end
