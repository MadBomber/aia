# frozen_string_literal: true

# lib/aia/tool_filter_strategy.rb
#
# Strategy resolver for A/B/C testing tool filtering approaches.
# Accepts a Hash of ToolFilter subclass instances keyed by symbol
# (e.g. {kbs: ..., tfidf: ..., zvec: ...}).
#
# Single filter  -> run that filter, display timing
# Multiple filters -> comparison mode with side-by-side display
#
# After each resolve(), prints a timing comparison table showing
# prep and filter times for all registered filters.

module AIA
  class ToolFilterStrategy
    # Maps filter keys to display info.
    FILTER_META = {
      kbs:        { letter: "A", label: "KBS",    score_label: "score" },
      tfidf:      { letter: "B", label: "TF-IDF", score_label: "score" },
      zvec:       { letter: "C", label: "Zvec",   score_label: "similarity" },
      sqlite_vec: { letter: "D", label: "SqVec",  score_label: "similarity" },
      lsi:        { letter: "E", label: "LSI",    score_label: "similarity" },
    }.freeze

    # @param filters [Hash{Symbol => ToolFilter}] e.g. {kbs: kbs_filter, tfidf: tfidf_filter}
    # @param ui_presenter [UIPresenter, nil] for display (unused currently, reserved)
    def initialize(filters: {}, ui_presenter: nil)
      @filters      = filters
      @ui_presenter = ui_presenter
    end

    # Resolve the tool list for this turn based on the active strategy.
    #
    # @param prompt [String] the user's processed prompt
    # @return [Array<String>, nil] tool names to allow, or nil for all tools
    def resolve(prompt)
      active = available_filters

      if active.size > 1
        resolve_comparison(prompt, active)
      elsif active.size == 1
        resolve_single(prompt, active.first)
      else
        # No filters — all tools available
        nil
      end
    end

    # @return [String] label for the active strategy (used in debug logging)
    def active_strategy_label
      labels = available_filters.map { |key, _| meta_for(key)[:label] }
      labels = ["KBS"] if labels.empty?  # fallback
      labels.size > 1 ? labels.join("+") + " comparison" : labels.first
    end

    private

    # Filters that are actually available (have indexed tools).
    def available_filters
      @filters.select { |_key, filter| filter.available? }
    end

    # Meta info for a filter key, with fallback for unknown keys.
    def meta_for(key)
      FILTER_META[key] || { letter: key.to_s[0].upcase, label: key.to_s, score_label: "score" }
    end

    # Single filter path: run filter, display results and timing.
    def resolve_single(prompt, (key, filter))
      filter_ms = run_filter_timed(key, filter, prompt)
      scored = filter_ms[:scored]

      display_filter_results(key, scored)
      display_timing_table({ key => filter_ms[:ms] })

      names = scored.map { |e| e[:name] }
      names.empty? ? nil : names
    end

    # Comparison mode: run all active filters, display side-by-side, ask user to pick.
    def resolve_comparison(prompt, active)
      results = {}  # key => {scored:, ms:}

      active.each do |key, filter|
        results[key] = run_filter_timed(key, filter, prompt)
      end

      display_multi_comparison(results)
      display_timing_table(results.transform_values { |r| r[:ms] })

      choice = prompt_multi_choice(active)
      pick_tools_by_choice(choice, results)
    end

    # Run a filter and return {scored:, ms:}.
    # For KBS, uses the pre-recorded last_turn_ms instead of timing filter_with_scores.
    def run_filter_timed(key, filter, prompt)
      if key == :kbs
        scored = filter.filter_with_scores(prompt)
        { scored: scored, ms: filter.last_turn_ms }
      else
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        scored = filter.filter_with_scores(prompt)
        ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        { scored: scored, ms: ms }
      end
    end

    # Display single-filter results to $stderr.
    def display_filter_results(key, scored)
      meta = meta_for(key)

      if scored.empty?
        $stderr.puts "\n[#{meta[:label]}] No tools matched (all tools available)"
        return
      end

      names = scored.map { |e| e[:name] }.join(', ')
      $stderr.puts "\n[#{meta[:label]}] Tools for this turn (#{scored.size}): #{names}"

      scored.each do |entry|
        $stderr.puts "[#{meta[:label]}]   #{entry[:name]}  (#{meta[:score_label]}: #{format('%.4f', entry[:score])})"
      end
    end

    # Display multi-strategy comparison to $stderr.
    def display_multi_comparison(results)
      $stderr.puts "\n#{'=' * 60}"
      $stderr.puts "  Tool Filter Comparison"
      $stderr.puts "#{'=' * 60}"

      results.each do |key, data|
        meta = meta_for(key)
        scored = data[:scored]

        $stderr.puts "\n  [#{meta[:letter]}] #{meta[:label]} (#{scored.size} tools):"
        if scored.empty?
          $stderr.puts "      (none matched threshold)"
        else
          scored.each do |entry|
            $stderr.puts "      - #{entry[:name]}  (#{meta[:score_label]}: #{format('%.4f', entry[:score])})"
          end
        end
      end

      display_overlap_stats(results)
      $stderr.puts "#{'=' * 60}"
    end

    # Show overlap statistics between active strategies.
    def display_overlap_stats(results)
      sets = results.transform_values { |data| data[:scored].map { |e| e[:name] } }
      return if sets.size < 2

      letters = results.keys.map { |k| meta_for(k)[:letter] }
      pairs = sets.keys.combination(2).map do |k1, k2|
        l1 = meta_for(k1)[:letter]
        l2 = meta_for(k2)[:letter]
        overlap = (sets[k1] & sets[k2]).size
        "#{l1}\u2229#{l2}: #{overlap}"
      end

      all_overlap = sets.values.reduce(:&).size
      $stderr.puts "\n  Overlap: #{pairs.join('  |  ')}  |  All: #{all_overlap}"
    end

    # Prompt user to pick a strategy in multi-comparison mode.
    def prompt_multi_choice(active)
      options = active.map { |key, _| "[#{meta_for(key)[:letter]}]#{meta_for(key)[:label]}" }
      options << "[M]erge"
      default_letter = meta_for(active.keys.first)[:letter]

      $stderr.print "  Choose: #{options.join(' / ')} (default: #{default_letter}): "
      input = $stdin.gets
      return default_letter.downcase if input.nil?
      input.strip.downcase[0] || default_letter.downcase
    rescue StandardError
      default_letter.downcase
    end

    # Return the tool list based on user's choice letter.
    def pick_tools_by_choice(choice, results)
      # Check if choice matches a specific filter's letter
      results.each do |key, data|
        if meta_for(key)[:letter].downcase == choice
          tools = data[:scored].map { |e| e[:name] }
          return tools.empty? ? nil : tools
        end
      end

      # Merge mode
      if choice == "m"
        merged = results.values.flat_map { |data| data[:scored].map { |e| e[:name] } }.uniq
        return merged.empty? ? nil : merged
      end

      # Default: first filter
      first_data = results.values.first
      tools = first_data[:scored].map { |e| e[:name] }
      tools.empty? ? nil : tools
    end

    # Print the timing comparison table to $stderr.
    # Dynamically includes columns for all registered filters.
    def display_timing_table(filter_ms_by_key)
      columns = @filters.map do |key, filter|
        meta = meta_for(key)
        active = filter_ms_by_key.key?(key)
        {
          header: "Option #{meta[:letter]}",
          sub:    "(#{meta[:label]})",
          prep:   active ? fmt_ms(filter.prep_ms) : "--",
          filter: active ? fmt_ms(filter_ms_by_key[key]) : "--"
        }
      end

      return if columns.empty?

      pw = 7  # "Process" column width
      widths = columns.map do |col|
        [10, col[:header].length, col[:sub].length, col[:prep].length, col[:filter].length].max
      end

      $stderr.puts
      # Top border
      $stderr.puts "┌─#{'─' * pw}─" + columns.each_with_index.map { |_, i| "┬─#{'─' * widths[i]}─" }.join + "┐"
      # Header row
      $stderr.puts "│ #{'Process'.ljust(pw)} " + columns.each_with_index.map { |col, i| "│ #{col[:header].ljust(widths[i])} " }.join + "│"
      # Sub-header row
      $stderr.puts "│ #{' ' * pw} " + columns.each_with_index.map { |col, i| "│ #{col[:sub].ljust(widths[i])} " }.join + "│"
      # Separator
      $stderr.puts "├─#{'─' * pw}─" + columns.each_with_index.map { |_, i| "┼─#{'─' * widths[i]}─" }.join + "┤"
      # Prep row
      $stderr.puts "│ #{'prep'.ljust(pw)} " + columns.each_with_index.map { |col, i| "│ #{col[:prep].rjust(widths[i])} " }.join + "│"
      # Filter row
      $stderr.puts "│ #{'filter'.ljust(pw)} " + columns.each_with_index.map { |col, i| "│ #{col[:filter].rjust(widths[i])} " }.join + "│"
      # Bottom border
      $stderr.puts "└─#{'─' * pw}─" + columns.each_with_index.map { |_, i| "┴─#{'─' * widths[i]}─" }.join + "┘"
    end

    def fmt_ms(ms)
      "#{ms.round(1)}ms"
    end
  end
end
