# lib/aia/directives/configuration.rb

module AIA
  module Directives
    module Configuration
      def self.config(args = [], context_manager = nil)
          args = Array(args)

          if args.empty?
            ap AIA.config
            ""
          elsif args.length == 1
            config_item = args.first
            local_cfg = Hash.new
            local_cfg[config_item] = AIA.config[config_item]
            ap local_cfg
            ""
          else
            config_item = args.shift
            boolean = AIA.respond_to?("#{config_item}?")
            new_value = args.join(' ').gsub('=', '').strip

            if boolean
              new_value = %w[true t yes y on 1 yea yeah yep yup].include?(new_value.downcase)
            end

            AIA.config[config_item] = new_value
            ""
          end
        end

      def self.model(args, context_manager = nil)
          if args.empty?
            # Display details for all configured models
            puts
            models = Array(AIA.config.model)

            if models.size == 1
              puts "Current Model:"
              puts "=============="
              puts AIA.config.client.model.to_h.pretty_inspect
            else
              puts "Multi-Model Configuration:"
              puts "=========================="
              puts "Model count: #{models.size}"
              puts "Primary model: #{models.first} (used for consensus when --consensus flag is enabled)"
              puts "Consensus mode: #{AIA.config.consensus.nil? ? 'auto-detect (disabled by default)' : AIA.config.consensus}"
              puts
              puts "Model Details:"
              puts "-" * 50

              models.each_with_index do |model_name, index|
                puts "#{index + 1}. #{model_name}#{index == 0 ? ' (primary)' : ''}"

                # Try to get model details if available
                begin
                  # Access the model details from RubyLLM's model registry
                  model_info = RubyLLM::Models.find(name: model_name)
                  if model_info
                    puts "   Provider: #{model_info.provider || 'Unknown'}"
                    puts "   Context window: #{model_info.context_window || 'Unknown'}"
                    puts "   Input cost: $#{model_info.input_cost || 'Unknown'}"
                    puts "   Output cost: $#{model_info.output_cost || 'Unknown'}"
                    puts "   Mode: #{model_info.modalities || 'Unknown'}"
                    puts "   Capabilities: #{(model_info.capabilities || []).join(', ')}" if model_info.capabilities&.any?
                  else
                    puts "   Details: Model not found in registry"
                  end
                rescue StandardError => e
                  puts "   Details: Unable to fetch (#{e.class.name}: #{e.message})"
                end
                puts
              end
            end
            puts
          else
            send(:config, args.prepend('model'), context_manager)
          end

          return ''
        end

      def self.temperature(args, context_manager = nil)
          send(:config, args.prepend('temperature'), context_manager)
        end

      def self.top_p(args, context_manager = nil)
          send(:config, args.prepend('top_p'), context_manager)
        end

      # NOTE: clear, review, checkpoint, and restore directives have been moved to
      # lib/aia/directives/checkpoint.rb which uses RubyLLM's Chat.@messages
      # as the source of truth for conversation history.

      # Set up aliases - these work on the module's singleton class
      class << self
        alias_method :cfg, :config
        alias_method :temp, :temperature
        alias_method :topp, :top_p
      end
    end
  end
end
