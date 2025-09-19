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

          # Manual descriptions for all directives
          directive_descriptions = {
            # Configuration directives
            'config' => 'View or set configuration values',
            'model' => 'View or change the AI model',
            'temperature' => 'Set the temperature parameter for AI responses',
            'top_p' => 'Set the top_p parameter for AI responses',
            'clear' => 'Clear the conversation context',
            'review' => 'Display the current conversation context with checkpoint markers',
            'checkpoint' => 'Create a named checkpoint of the current context',
            'restore' => 'Restore context to a previous checkpoint',

            # Utility directives
            'tools' => 'List available tools',
            'next' => 'Set the next prompt in the sequence',
            'pipeline' => 'Set or view the prompt workflow sequence',
            'terse' => 'Add instruction for concise responses',
            'robot' => 'Display ASCII robot art',

            # Execution directives
            'ruby' => 'Execute Ruby code',
            'shell' => 'Execute shell commands',
            'say' => 'Use text-to-speech to speak the text',

            # Web and File directives
            'webpage' => 'Fetch and include content from a webpage',
            'include' => 'Include content from a file',
            'include_file' => 'Include file content (internal use)',
            'included_files' => 'List files that have been included',
            'included_files=' => 'Set the list of included files',

            # Model directives
            'available_models' => 'List all available AI models',
            'compare' => 'Compare responses from multiple models',
            'help' => 'Show this help message',

            # Aliases (these get their descriptions from main directive)
            'cfg' => nil,  # alias for config
            'temp' => nil, # alias for temperature
            'topp' => nil, # alias for top_p
            'context' => nil, # alias for review
            'cp' => nil, # alias for checkpoint
            'workflow' => nil, # alias for pipeline
            'rb' => nil, # alias for ruby
            'sh' => nil, # alias for shell
            'web' => nil, # alias for webpage
            'website' => nil, # alias for webpage
            'import' => nil, # alias for include
            'models' => nil, # alias for available_models
            'all_models' => nil, # alias for available_models
            'am' => nil, # alias for available_models
            'llms' => nil, # alias for available_models
            'available' => nil, # alias for available_models
            'cmp' => nil, # alias for compare
          }

          # Get all registered directive modules from the Registry
          all_modules = [
            AIA::Directives::WebAndFile,
            AIA::Directives::Utility,
            AIA::Directives::Configuration,
            AIA::Directives::Execution,
            AIA::Directives::Models
          ]

          all_directives = {}
          excluded_methods = ['run', 'initialize', 'private?', 'descriptions', 'aliases', 'build_aliases',
                             'desc', 'method_added', 'register_directive_module', 'process',
                             'directive?', 'prefix_size']

          # Collect directives from all modules
          all_modules.each do |mod|
            methods = mod.methods(false).map(&:to_s).reject { |m| excluded_methods.include?(m) }

            methods.each do |method|
              # Skip if this is an alias (has nil description)
              next if directive_descriptions.key?(method) && directive_descriptions[method].nil?

              description = directive_descriptions[method] || method.gsub('_', ' ').capitalize

              all_directives[method] = {
                module: mod.name.split('::').last,
                description: description,
                aliases: []
              }
            end
          end

          # Manually map known aliases
          alias_mappings = {
            'config' => ['cfg'],
            'temperature' => ['temp'],
            'top_p' => ['topp'],
            'review' => ['context'],
            'checkpoint' => ['cp'],
            'pipeline' => ['workflow'],
            'ruby' => ['rb'],
            'shell' => ['sh'],
            'webpage' => ['web', 'website'],
            'include' => ['import'],
            'available_models' => ['models', 'all_models', 'am', 'llms', 'available'],
            'compare' => ['cmp']
          }

          # Apply alias mappings
          alias_mappings.each do |directive, aliases|
            if all_directives[directive]
              all_directives[directive][:aliases] = aliases
            end
          end

          # Sort and display directives by category
          categories = {
            'Configuration' => ['config', 'model', 'temperature', 'top_p', 'clear', 'review', 'checkpoint', 'restore'],
            'Utility' => ['tools', 'next', 'pipeline', 'terse', 'robot', 'help'],
            'Execution' => ['ruby', 'shell', 'say'],
            'Web & Files' => ['webpage', 'include'],
            'Models' => ['available_models', 'compare']
          }

          categories.each do |category, directives|
            puts "#{category}:"
            puts "-" * category.length

            directives.each do |directive|
              info = all_directives[directive]
              next unless info

              if info[:aliases] && !info[:aliases].empty?
                with_prefix = info[:aliases].map { |m| PromptManager::Prompt::DIRECTIVE_SIGNAL + m }
                alias_text = " (aliases: #{with_prefix.join(', ')})"
              else
                alias_text = ""
              end

              puts "  //#{directive}#{alias_text}"
              puts "      #{info[:description]}"
              puts
            end
          end

          # Show any uncategorized directives
          categorized = categories.values.flatten
          uncategorized = all_directives.keys - categorized - ['include_file', 'included_files', 'included_files=']

          if uncategorized.any?
            puts "Other:"
            puts "------"
            uncategorized.sort.each do |directive|
              info = all_directives[directive]
              puts "  //#{directive}"
              puts "      #{info[:description]}"
              puts
            end
          end

          puts "\nTotal: #{all_directives.size} directives available"
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
