# lib/aia/directives/models.rb

module AIA
  module Directives
    module Models
      class << self
        def descriptions
          @descriptions ||= {}
        end

        def aliases
          @aliases ||= {}
        end

        def build_aliases(methods)
          methods.each do |method_name|
            method = self.method(method_name)
            aliases[method_name] = []

            methods.each do |other_method_name|
              next if method_name == other_method_name
              other_method = self.method(other_method_name)

              if method == other_method
                aliases[method_name] << other_method_name
              end
            end
          end
        end
      end

      def self.available_models(args = nil, context_manager = nil)
          query = args

          if 1 == query.size
            query = query.first.split(',')
          end

          header = "\nAvailable LLMs"
          header += " for #{query.join(' and ')}" if query

          puts header + ':'
          puts

          q1 = query.select { |q| q.include?('_to_') } # SMELL: ??
          q2 = query.reject { |q| q.include?('_to_') }

          counter = 0

          RubyLLM.models.all.each do |llm|
            cw = llm.context_window
            caps = llm.capabilities.join(',')
            inputs = llm.modalities.input.join(',')
            outputs = llm.modalities.output.join(',')
            mode = "#{inputs} to #{outputs}"
            in_1m = llm.pricing.text_tokens.standard.to_h[:input_per_million]
            entry = "- #{llm.id} (#{llm.provider}) in: $#{in_1m} cw: #{cw} mode: #{mode} caps: #{caps}"

            if query.nil? || query.empty?
              counter += 1
              puts entry
              next
            end

            show_it = true
            q1.each { |q| show_it &&= llm.modalities.send("#{q}?") }
            q2.each { |q| show_it &&= entry.include?(q) }

            if show_it
              counter += 1
              puts entry
            end
          end

          puts if counter > 0
          puts "#{counter} LLMs matching your query"
          puts

          ""
        end

      def self.help(args = nil, context_manager = nil)
          puts
          puts "Available Directives"
          puts "===================="
          puts

          directives = self.methods(false).map(&:to_s).reject do |m|
            ['run', 'initialize', 'private?', 'descriptions', 'aliases', 'build_aliases'].include?(m)
          end.sort

          build_aliases(directives)

          directives.each do |directive|
            next unless descriptions[directive]

            others = aliases[directive]

            if others.empty?
              others_line = ""
            else
              with_prefix = others.map { |m| PromptManager::Prompt::DIRECTIVE_SIGNAL + m }
              others_line = "\tAliases:#{with_prefix.join('  ')}\n"
            end

            puts <<~TEXT
              //#{directive} #{descriptions[directive]}
              #{others_line}
            TEXT
          end

          ""
        end

      def self.compare(args, context_manager = nil)
          return 'Error: No prompt provided for comparison' if args.empty?

          # Parse arguments - first arg is the prompt, --models flag specifies models
          prompt = nil
          models = []

          i = 0
          while i < args.length
            if args[i] == '--models' && i + 1 < args.length
              models = args[i + 1].split(',')
              i += 2
            else
              prompt ||= args[i]
              i += 1
            end
          end

          return 'Error: No prompt provided for comparison' unless prompt
          return 'Error: No models specified. Use --models model1,model2,model3' if models.empty?

          puts "\nComparing responses for: #{prompt}\n"
          puts '=' * 80

          results = {}

          models.each do |model_name|
            model_name.strip!
            puts "\n🤖 **#{model_name}:**"
            puts '-' * 40

            begin
              # Create a temporary chat instance for this model
              chat = RubyLLM.chat(model: model_name)
              response = chat.ask(prompt)
              content = response.content

              puts content
              results[model_name] = content
            rescue StandardError => e
              error_msg = "Error with #{model_name}: #{e.message}"
              puts error_msg
              results[model_name] = error_msg
            end
          end

          puts '\n' + '=' * 80
          puts "\nComparison complete!"

          ''
        end

      # Set up aliases - these work on the module's singleton class
      class << self
        alias_method :am, :available_models
        alias_method :available, :available_models
        alias_method :models, :available_models
        alias_method :all_models, :available_models
        alias_method :llms, :available_models
        alias_method :cmp, :compare
      end
    end
  end
end
