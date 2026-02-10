# lib/aia/directives/model_directives.rb

module AIA
  class ModelDirectives < Directive
    desc "List all available AI models"
    def available_models(args = nil, context_manager = nil)
      current_models = AIA.config.models

      model_names = current_models.map do |m|
        m.respond_to?(:name) ? m.name : m.to_s
      end

      using_local_provider = model_names.any? { |m| m.start_with?('ollama/', 'lms/') }

      if using_local_provider
        show_local_models(model_names, args)
      else
        show_rubyllm_models(args)
      end

      ""
    end
    alias_method :am,         :available_models
    alias_method :available,   :available_models
    alias_method :models,      :available_models
    alias_method :all_models,  :available_models
    alias_method :llms,        :available_models

    desc "Compare responses from multiple models"
    def compare(args, context_manager = nil)
      return 'Error: No prompt provided for comparison' if args.empty?

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
    alias_method :cmp, :compare

    # --- helpers (no desc → not registered) ---

    def show_local_models(current_models, args)
      require 'net/http'
      require 'json'

      puts "\nLocal LLM Models:"
      puts

      current_models.each do |model_spec|
        if model_spec.start_with?('ollama/')
          api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434')
          api_base = api_base.gsub(%r{/v1/?$}, '')
          show_ollama_models(api_base, args)
        elsif model_spec.start_with?('lms/')
          api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234')
          show_lms_models(api_base, args)
        end
      end
    end

    def show_ollama_models(api_base, args)
      begin
        uri = URI("#{api_base}/api/tags")
        response = Net::HTTP.get_response(uri)

        unless response.is_a?(Net::HTTPSuccess)
          puts "❌ Cannot connect to Ollama at #{api_base}"
          return
        end

        data = JSON.parse(response.body)
        models = data['models'] || []

        if models.empty?
          puts "No Ollama models found"
          return
        end

        puts "Ollama Models (#{api_base}):"
        puts "-" * 60

        counter = 0
        models.each do |model|
          name = model['name']
          size = model['size'] ? format_bytes(model['size']) : 'unknown'
          modified = model['modified_at'] ? Time.parse(model['modified_at']).strftime('%Y-%m-%d') : 'unknown'

          entry = "- ollama/#{name} (size: #{size}, modified: #{modified})"

          if args.nil? || args.empty? || args.any? { |q| entry.downcase.include?(q.downcase) }
            puts entry
            counter += 1
          end
        end

        puts
        puts "#{counter} Ollama model(s) available"
        puts
      rescue StandardError => e
        puts "❌ Error fetching Ollama models: #{e.message}"
      end
    end

    def show_lms_models(api_base, args)
      begin
        uri = URI("#{api_base.gsub(%r{/v1/?$}, '')}/v1/models")
        response = Net::HTTP.get_response(uri)

        unless response.is_a?(Net::HTTPSuccess)
          puts "❌ Cannot connect to LM Studio at #{api_base}"
          return
        end

        data = JSON.parse(response.body)
        models = data['data'] || []

        if models.empty?
          puts "No LM Studio models found"
          return
        end

        puts "LM Studio Models (#{api_base}):"
        puts "-" * 60

        counter = 0
        models.each do |model|
          name = model['id']
          entry = "- lms/#{name}"

          if args.nil? || args.empty? || args.any? { |q| entry.downcase.include?(q.downcase) }
            puts entry
            counter += 1
          end
        end

        puts
        puts "#{counter} LM Studio model(s) available"
        puts
      rescue StandardError => e
        puts "❌ Error fetching LM Studio models: #{e.message}"
      end
    end

    def format_bytes(bytes)
      units = ['B', 'KB', 'MB', 'GB', 'TB']
      return "0 B" if bytes.zero?

      exp = (Math.log(bytes) / Math.log(1024)).to_i
      exp = [exp, units.length - 1].min

      "%.1f %s" % [bytes.to_f / (1024 ** exp), units[exp]]
    end

    def show_rubyllm_models(args)
      query = args

      if query && 1 == query.size
        query = query.first.split(',')
      end

      header = "\nAvailable LLMs"
      header += " for #{query.join(' and ')}" if query

      puts header + ':'
      puts

      q1 = query ? query.select { |q| q.include?('_to_') } : []
      q2 = query ? query.reject { |q| q.include?('_to_') } : []

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
    end
  end
end
