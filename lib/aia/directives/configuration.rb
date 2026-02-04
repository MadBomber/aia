# lib/aia/directives/configuration.rb

module AIA
  module Directives
    module Configuration
      def self.config(args = [], context_manager = nil)
          args = Array(args)

          if args.empty?
            ap AIA.config.to_h
            ""
          elsif args.length == 1
            config_item = args.first
            local_cfg = {}
            # Use method-based access for MywayConfig::Base
            if AIA.config.respond_to?(config_item)
              local_cfg[config_item] = AIA.config.send(config_item)
            else
              local_cfg[config_item] = nil
            end
            ap local_cfg
            ""
          else
            config_item = args.shift
            boolean = AIA.respond_to?("#{config_item}?")
            new_value = args.join(' ').gsub('=', '').strip

            if boolean
              new_value = %w[true t yes y on 1 yea yeah yep yup].include?(new_value.downcase)
            end

            # Use method-based setter for MywayConfig::Base
            setter = "#{config_item}="
            if AIA.config.respond_to?(setter)
              AIA.config.send(setter, new_value)
            else
              puts "Warning: Unknown config option '#{config_item}'"
            end
            ""
          end
        end

      def self.model(args, context_manager = nil)
          if args.empty?
            # Display details for all configured models
            puts
            models = AIA.config.models

            if models.size == 1
              puts "Current Model:"
              puts "=============="
              puts AIA.client.model.to_h.pretty_inspect
            else
              puts "Multi-Model Configuration:"
              puts "=========================="
              puts "Model count: #{models.size}"
              first_model = models.first.respond_to?(:name) ? models.first.name : models.first.to_s
              puts "Primary model: #{first_model} (used for consensus when --consensus flag is enabled)"
              consensus = AIA.config.flags.consensus
              puts "Consensus mode: #{consensus.nil? ? 'auto-detect (disabled by default)' : consensus}"
              puts
              puts "Model Details:"
              puts "-" * 50

              models.each_with_index do |model_spec, index|
                model_name = model_spec.respond_to?(:name) ? model_spec.name : model_spec.to_s
                puts "#{index + 1}. #{model_name}#{index == 0 ? ' (primary)' : ''}"

                # Try to get model details if available
                begin
                  # Access the model details from RubyLLM's model registry
                  model_info = RubyLLM::Models.find(model_name)
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
            model_names = args.join(' ').split(',').map(&:strip).reject(&:empty?)
            AIA.config.models = AIA::Config::TO_MODEL_SPECS.call(model_names)
            AIA.client = AIA.client.class.new
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
