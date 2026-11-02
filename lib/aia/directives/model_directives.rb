# lib/aia/directives/model_directives.rb

require_relative '../modality_query'

module AIA
  class ModelDirectives < Directive
    desc "List all available AI models"
    def available_models(args = nil, context_manager = nil)
      positive_terms, negative_terms = parse_search_terms(Array(args))

      provider_slugs = configured_provider_slugs(AIA.config.models)

      if provider_slugs.any?
        show_provider_models(provider_slugs, positive_terms, negative_terms)
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

    # Provider slugs referenced by the configured models — from ModelSpec#provider
    # when present, else from a registered "<slug>/" name prefix (raw string
    # model specs). Entirely registry-driven; no provider names are hardcoded.
    def configured_provider_slugs(models)
      Array(models).filter_map do |m|
        if m.respond_to?(:provider) && m.provider
          m.provider.to_s
        else
          name = (m.respond_to?(:name) ? m.name : m).to_s
          prefix = name.split('/', 2).first if name.include?('/')
          prefix if AIA::ProviderRegistry.registered?(prefix)
        end
      end.uniq
    end

    # List each provider's live models through RubyLLM's own provider API
    # (Provider#list_models), the same path every registered provider —
    # built-in or gem-supplied — implements.
    # :reek:TooManyStatements -- sequential terminal report per provider: header, listing, connection guard
    def show_provider_models(provider_slugs, positive_terms = nil, negative_terms = nil)
      positive_terms, negative_terms = normalized_model_search_terms(positive_terms, negative_terms)

      provider_slugs.each do |slug|
        puts "\n#{slug} models:"
        puts "-" * 60

        entries = provider_model_entries(slug)
        print_filtered_entries(entries, positive_terms, negative_terms, "#{slug} model(s) available")
      rescue StandardError => e
        puts "❌ Cannot list models for provider '#{slug}': #{e.message}"
      end
    end

    # One "- <slug>/<model-id>" line per model the provider reports.
    def provider_model_entries(slug)
      provider = AIA::ProviderRegistry.instantiate(slug)
      provider.list_models.map { |model| "- #{slug}/#{model.id}" }
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

    # :reek:TooManyStatements -- sequential terminal report: header, filtered model listing, summary
    def show_rubyllm_models(positive_terms = nil, negative_terms = nil)
      positive_terms, negative_terms = normalized_model_search_terms(positive_terms, negative_terms)

      # expand comma-separated terms passed as a single token
      positive_terms = positive_terms.first.split(',') if positive_terms.size == 1

      puts rubyllm_header(positive_terms, negative_terms)
      puts

      # modality terms (e.g. "text_to_text") trigger capability checks; the rest
      # are plain substring filters applied to the formatted entry string
      modality_terms, substring_terms = positive_terms.partition { |q| ModalityQuery.modality_term?(q) }

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
      modality_terms.all? { |q| ModalityQuery.matches?(llm.modalities, q) } &&
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
