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

      def self.clear(args, context_manager = nil)
          if context_manager.nil?
            return "Error: Context manager not available for //clear directive."
          end

          context_manager.clear_context
          ''
        end

      def self.review(args, context_manager = nil)
          return "Error: Context manager not available for //review directive." if context_manager.nil?

          context = context_manager.get_context
          checkpoint_positions = context_manager.checkpoint_positions

          # Display context with checkpoint markers
          puts "\n=== Chat Context ==="
          puts "Total messages: #{context.size}"

          if checkpoint_positions.any?
            puts "Checkpoints: #{context_manager.checkpoint_names.join(', ')}"
          end

          puts "\n"

          context.each_with_index do |message, index|
            # Check if there's a checkpoint at this position
            if checkpoint_positions[index]
              checkpoint_names = checkpoint_positions[index].join(', ')
              puts "📍 [Checkpoint: #{checkpoint_names}]"
              puts "-" * 40
            end

            # Display the message
            role_display = message[:role].capitalize
            content_preview = message[:content].to_s

            # Truncate long content for display
            if content_preview.length > 200
              content_preview = content_preview[0..197] + "..."
            end

            puts "#{index + 1}. [#{role_display}]: #{content_preview}"
            puts ""
          end

          # Check if there's a checkpoint at the end (after all messages)
          if checkpoint_positions[context.size]
            checkpoint_names = checkpoint_positions[context.size].join(', ')
            puts "📍 [Checkpoint: #{checkpoint_names}]"
            puts "-" * 40
          end

          puts "=== End of Context ==="
          ''
        end

      def self.checkpoint(args, context_manager = nil)
          if context_manager.nil?
            return "Error: Context manager not available for //checkpoint directive."
          end

          name = args.empty? ? nil : args.join(' ').strip
          checkpoint_name = context_manager.create_checkpoint(name: name)
          puts "Checkpoint '#{checkpoint_name}' created."
          ""
      end

      def self.restore(args, context_manager = nil)
          if context_manager.nil?
            return "Error: Context manager not available for //restore directive."
          end

          name = args.empty? ? nil : args.join(' ').strip

          if context_manager.restore_checkpoint(name: name)
            restored_name = name || context_manager.checkpoint_names.last
            "Context restored to checkpoint '#{restored_name}'."
          else
            if name
              "Error: Checkpoint '#{name}' not found. Available checkpoints: #{context_manager.checkpoint_names.join(', ')}"
            else
              "Error: No checkpoints available to restore."
            end
          end
        end

      # Set up aliases - these work on the module's singleton class
      class << self
        alias_method :cfg, :config
        alias_method :temp, :temperature
        alias_method :topp, :top_p
        alias_method :context, :review
        alias_method :ckp, :checkpoint
      end
    end
  end
end
