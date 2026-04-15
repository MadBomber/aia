# lib/aia/directives/configuration_directives.rb

module AIA
  class ConfigurationDirectives < Directive
    state_setting! :model

    desc "View or set configuration values"
    def config(args = [], context_manager = nil)
      args = Array(args)

      if args.empty?
        ap AIA.config.to_h
        ""
      elsif args.length == 1
        config_item = args.first
        local_cfg = {}
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

        setter = "#{config_item}="
        if AIA.config.respond_to?(setter)
          AIA.config.send(setter, new_value)
        else
          warn "Warning: Unknown config option '#{config_item}'"
          AIA::LoggerManager.aia_logger.warn("Unknown config option '#{config_item}'")
        end
        ""
      end
    end
    alias_method :cfg, :config

    desc "View or change the AI model"
    def model(args, context_manager = nil)
      if args.empty?
        puts
        models = AIA.config.models

        if models.size == 1
          puts "Current Model:"
          puts "=============="
          model_name = models.first.respond_to?(:name) ? models.first.name : models.first.to_s
          begin
            model_info = RubyLLM::Models.find(model_name)
            puts model_info.to_h.pretty_inspect if model_info
          rescue StandardError
            puts "  #{model_name}"
          end
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

            begin
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
        AIA.client = RobotFactory.rebuild(AIA.config)
      end

      ''
    end

    desc "Set the temperature parameter for AI responses"
    def temperature(args, context_manager = nil)
      config(args.prepend('temperature'), context_manager)
    end
    alias_method :temp, :temperature

    desc "Set the top_p parameter for AI responses"
    def top_p(args, context_manager = nil)
      config(args.prepend('top_p'), context_manager)
    end
    alias_method :topp, :top_p

    desc "Dump session cost/token metrics as CSV"
    def cost(args = [], context_manager = nil)
      tracker = AIA.session_tracker
      unless tracker
        puts "No session tracker available."
        return ''
      end

      turns = tracker.turns.reject { |t| t[:type] == :model_switch }
      if turns.empty?
        puts "No turns recorded yet."
        return ''
      end

      has_similarity = turns.any? { |t| t.key?(:similarity) }

      header = %w[model input_tokens output_tokens total_tokens cost elapsed]
      header << 'similarity' if has_similarity
      lines  = [header.join(',')]

      turns.each do |turn|
        input_t  = turn[:input_tokens] || 0
        output_t = turn[:output_tokens] || 0
        total_t  = input_t + output_t
        cost_val = turn[:cost] || 0.0
        elapsed  = turn[:elapsed] || 0

        row = [
          turn[:model],
          input_t,
          output_t,
          total_t,
          "$#{'%.5f' % cost_val}",
          "%.1fs" % elapsed
        ]

        if has_similarity
          sim = turn[:similarity]
          row << (sim.nil? ? 'ref' : "%.1f%%" % (sim * 100))
        end

        lines << row.join(',')
      end

      # Totals
      total_input   = turns.sum { |t| t[:input_tokens] || 0 }
      total_output  = turns.sum { |t| t[:output_tokens] || 0 }
      total_tokens  = total_input + total_output
      total_cost    = turns.sum { |t| t[:cost] || 0.0 }
      max_elapsed   = turns.map { |t| t[:elapsed] || 0 }.max

      totals = [
        'TOTAL',
        total_input,
        total_output,
        total_tokens,
        "$#{'%.5f' % total_cost}",
        "%.1fs" % max_elapsed
      ]
      totals << '' if has_similarity
      lines << totals.join(',')

      csv = lines.join("\n")
      puts
      puts csv
      puts

      out_file = AIA.config.output&.file
      File.open(out_file, 'a') { |f| f.puts csv } if out_file

      ''
    end
  end
end
