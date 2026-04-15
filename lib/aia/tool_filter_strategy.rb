# frozen_string_literal: true

# lib/aia/tool_filter_strategy.rb
#
# Strategy resolver for A/B/C testing tool filtering approaches.
# Accepts a Hash of ToolFilter subclass instances keyed by symbol
# (e.g. {tfidf: ..., zvec: ..., sqlite_vec: ...}).
#
# Single filter  -> run that filter, display timing
# Multiple filters -> comparison mode with side-by-side display (Thread.new per filter)
#
# After each resolve(), prints a timing comparison table showing
# prep and filter times for all registered filters.

require 'timeout'

module AIA
  class ToolFilterStrategy
    # Maps filter keys to display info.
    FILTER_META = {
      tfidf:      { letter: "A", label: "TF-IDF", score_label: "score" },
      zvec:       { letter: "B", label: "Zvec",   score_label: "similarity" },
      sqlite_vec: { letter: "C", label: "SqVec",  score_label: "similarity" },
      lsi:        { letter: "D", label: "LSI",    score_label: "similarity" },
    }.freeze

    # Sentinel value for a filter that failed or timed out.
    # Excluded from display and tool selection.
    FilterError = Data.define(:filter_key, :error_message)

    DEFAULT_TIMEOUT_S = 10

    # @param filters [Hash{Symbol => ToolFilter}] e.g. {tfidf: tfidf_filter, zvec: zvec_filter}
    # @param ui_presenter [UIPresenter, nil] for display (unused currently, reserved)
    # @param timeout_s [Numeric] per-filter wall-clock timeout in seconds
    def initialize(filters: {}, ui_presenter: nil, timeout_s: DEFAULT_TIMEOUT_S)
      @filters      = filters
      @ui_presenter = ui_presenter
      @timeout_s    = timeout_s
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
      labels = ["none"] if labels.empty?  # fallback
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
    rescue => e
      $stderr.puts "\n[#{meta_for(key)[:label]}] Filter failed: #{e.message}"
      nil
    end

    # Comparison mode: run all active filters concurrently (Thread.new per filter).
    # Failed or timed-out filters produce a FilterError sentinel and are excluded
    # from display and selection. Returns nil if all filters fail.
    # Auto-selects tfidf if available, otherwise the first valid filter.
    def resolve_comparison(prompt, active)
      threads = active.map do |key, filter|
        thread = Thread.new do
          Timeout.timeout(@timeout_s) { run_filter_timed(key, filter, prompt) }
        rescue Timeout::Error
          FilterError.new(filter_key: key, error_message: "timed out after #{@timeout_s}s")
        rescue => e
          FilterError.new(filter_key: key, error_message: e.message)
        end
        [key, thread]
      end

      results = {}
      threads.each { |key, thread| results[key] = thread.value }

      valid_results = results.reject { |_, v| v.is_a?(FilterError) }
      return nil if valid_results.empty?

      if valid_results.size == 1
        key, data = valid_results.first
        display_filter_results(key, data[:scored]) if AIA.debug?
        display_timing_table({ key => data[:ms] }) if AIA.debug?
        tools = data[:scored].map { |e| e[:name] }
        return tools.empty? ? nil : tools
      end

      display_multi_comparison(valid_results) if AIA.debug?
      display_timing_table(valid_results.transform_values { |r| r[:ms] }) if AIA.debug?

      # Auto-select: prefer tfidf, otherwise first available
      preferred_key = valid_results.key?(:tfidf) ? :tfidf : valid_results.keys.first
      tools = valid_results[preferred_key][:scored].map { |e| e[:name] }
      tools.empty? ? nil : tools
    end

    # Run a filter and return {scored:, ms:}.
    def run_filter_timed(key, filter, prompt)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      scored = filter.filter_with_scores(prompt)
      ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
      { scored: scored, ms: ms }
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
