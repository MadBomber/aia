# lib/aia/directives/model_directives.rb

module AIA
  class ModelDirectives < Directive
    desc "List all available AI models"
    def available_models(args = nil, context_manager = nil)
      current_models = AIA.config.models

      model_names = current_models.map do |m|
        m.respond_to?(:name) ? m.name : m.to_s
      end

      positive_terms, negative_terms = parse_search_terms(Array(args))

      using_local_provider = model_names.any? { |m| m.start_with?('ollama/', 'lms/') }

      if using_local_provider
        show_local_models(model_names, positive_terms, negative_terms)
      else
        show_rubyllm_models(positive_terms, negative_terms)
      end

      ""
    end
    alias am available_models
    alias available available_models
    alias models available_models
    alias all_models available_models
    alias llms available_models

    desc "Compare responses from multiple models"
    def compare(args, context_manager = nil)
      prompt, models = parse_compare_args(args)

      return report_error('Error: No prompt provided for comparison') unless prompt
      return report_error('Error: No models specified. Use --models model1,model2,model3') if models.empty?

      puts "\nComparing responses for: #{prompt}\n"
      puts '=' * 80

      models.each { |model_name| compare_with_model(model_name.strip, prompt) }

      puts "\n" + ('=' * 80)
      puts "\nComparison complete!"

      ''
    end
    alias cmp compare

    # --- helpers (no desc → not registered) ---

    # Split a //compare arg list into [prompt, models]; the first non-flag
    # token is the prompt, `--models a,b,c` supplies the model list.
    def parse_compare_args(args)
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

      [prompt, models]
    end

    def compare_with_model(model_name, prompt)
      puts "\n🤖 **#{model_name}:**"
      puts '-' * 40

      response = RubyLLM.chat(model: model_name).ask(prompt)
      puts response.content
    rescue StandardError => e
      puts "Error with #{model_name}: #{e.message}"
    end

    # Log and print a directive error, then return nil so the chat loop
    # skips forwarding it to the robot (an error is not conversational output).
    def report_error(msg)
      AIA::LoggerManager.aia_logger.error(msg)
      puts msg
      nil
    end

    def show_local_models(current_models, positive_terms = nil, negative_terms = nil)
      require 'net/http'
      require 'json'

      positive_terms, negative_terms = normalized_model_search_terms(positive_terms, negative_terms)

      puts "\nLocal LLM Models:"
      puts

      current_models.each do |model_spec|
        if model_spec.start_with?('ollama/')
          api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434')
          api_base = api_base.gsub(%r{/v1/?$}, '')
          show_ollama_models(api_base, positive_terms, negative_terms)
        elsif model_spec.start_with?('lms/')
          api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234')
          show_lms_models(api_base, positive_terms, negative_terms)
        end
      end
    end

    # :reek:TooManyStatements -- sequential terminal report: fetch, connection guards, filtered listing
    def show_ollama_models(api_base, positive_terms = nil, negative_terms = nil)
      positive_terms, negative_terms = normalized_model_search_terms(positive_terms, negative_terms)

      data = fetch_json("#{api_base}/api/tags")
      if data.nil?
        puts "❌ Cannot connect to Ollama at #{api_base}"
        return
      end

      models = data['models'] || []
      if models.empty?
        puts "No Ollama models found"
        return
      end

      puts "Ollama Models (#{api_base}):"
      puts "-" * 60

      entries = models.map { |model| format_ollama_entry(model) }
      print_filtered_entries(entries, positive_terms, negative_terms, "Ollama model(s) available")
    rescue StandardError => e
      puts "❌ Error fetching Ollama models: #{e.message}"
    end

    def format_ollama_entry(model)
      size     = model['size'] ? format_bytes(model['size']) : 'unknown'
      modified = model['modified_at'] ? Time.parse(model['modified_at']).strftime('%Y-%m-%d') : 'unknown'
      "- ollama/#{model['name']} (size: #{size}, modified: #{modified})"
    end

    # Fetch and parse JSON from a local model server; nil unless HTTP success.
    def fetch_json(uri_string)
      uri  = URI(uri_string)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5
      response = http.request(Net::HTTP::Get.new(uri))
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    # The entry is a String; Array#intersect? would raise TypeError
    def entry_matches?(entry_lc, positive_terms, negative_terms)
      (positive_terms.empty? || positive_terms.any? { |q| entry_lc.include?(q) }) &&
        negative_terms.none? { |q| entry_lc.include?(q) }
    end

    def print_filtered_entries(entries, positive_terms, negative_terms, summary_label)
      counter = 0
      entries.each do |entry|
        next unless entry_matches?(entry.downcase, positive_terms, negative_terms)

        puts entry
        counter += 1
      end

      puts
      puts "#{counter} #{summary_label}"
      puts
    end

    # :reek:TooManyStatements -- sequential terminal report: fetch, connection guards, filtered listing
    def show_lms_models(api_base, positive_terms = nil, negative_terms = nil)
      positive_terms, negative_terms = normalized_model_search_terms(positive_terms, negative_terms)

      data = fetch_json("#{api_base.gsub(%r{/v1/?$}, '')}/v1/models")
      if data.nil?
        puts "❌ Cannot connect to LM Studio at #{api_base}"
        return
      end

      models = data['data'] || []
      if models.empty?
        puts "No LM Studio models found"
        return
      end

      puts "LM Studio Models (#{api_base}):"
      puts "-" * 60

      entries = models.map { |model| "- lms/#{model['id']}" }
      print_filtered_entries(entries, positive_terms, negative_terms, "LM Studio model(s) available")
    rescue StandardError => e
      puts "❌ Error fetching LM Studio models: #{e.message}"
    end

    def format_bytes(bytes)
      units = %w[B KB MB GB TB]
      return "0 B" if bytes.zero?

      exp = (Math.log(bytes) / Math.log(1024)).to_i
      exp = [exp, units.length - 1].min

      "%.1f %s" % [bytes.to_f / (1024**exp), units[exp]]
    end

    # :reek:TooManyStatements -- sequential terminal report: header, filtered model listing, summary
    def show_rubyllm_models(positive_terms = nil, negative_terms = nil)
      positive_terms, negative_terms = normalized_model_search_terms(positive_terms, negative_terms)

      # expand comma-separated terms passed as a single token
      positive_terms = positive_terms.first.split(',') if positive_terms.size == 1

      puts rubyllm_header(positive_terms, negative_terms)
      puts

      # modality terms (e.g. "text_to_text") trigger capability checks; the rest
      # are plain substring filters applied to the formatted entry string
      modality_terms, substring_terms = positive_terms.partition { |q| q.include?('_to_') }

      counter = 0
      RubyLLM.models.all.each do |llm|
        entry = format_rubyllm_entry(llm)
        next unless rubyllm_entry_visible?(llm, entry, modality_terms, substring_terms, negative_terms)

        counter += 1
        puts entry
      end

      puts if counter.positive?
      puts "#{counter} LLMs matching your query"
      puts
    end

    def rubyllm_header(positive_terms, negative_terms)
      header = "\nAvailable LLMs"
      header += " for #{positive_terms.join(' and ')}" if positive_terms.any?
      header += " (excluding: #{negative_terms.join(', ')})" if negative_terms.any?
      header + ':'
    end

    def format_rubyllm_entry(llm)
      modalities = llm.modalities
      mode  = "#{modalities.input.join(',')} to #{modalities.output.join(',')}"
      in_1m = llm.pricing.text_tokens.standard.to_h[:input_per_million]
      "- #{llm.id} (#{llm.provider}) in: $#{in_1m} cw: #{llm.context_window} mode: #{mode} caps: #{llm.capabilities.join(',')}"
    end

    def rubyllm_entry_visible?(llm, entry, modality_terms, substring_terms, negative_terms)
      modality_terms.all? { |q| llm.modalities.send("#{q}?") } &&
        substring_terms.all? { |q| entry.include?(q) } &&
        negative_terms.none? { |q| entry.downcase.include?(q) }
    end

    def normalized_model_search_terms(positive_terms, negative_terms = nil)
      return parse_search_terms(Array(positive_terms)) if negative_terms.nil?

      [
        Array(positive_terms).compact.map { |term| term.to_s.downcase },
        Array(negative_terms).compact.map { |term| term.to_s.downcase }
      ]
    end
  end
end
