# frozen_string_literal: true

# lib/aia/tool_filter_strategy.rb
#
# Strategy resolver for TF-IDF tool filtering (Option A).
# Accepts a Hash of ToolFilter subclass instances keyed by symbol.
#
# After each resolve(), prints a timing table showing
# prep and filter times for the active filter.

module AIA
  class ToolFilterStrategy
    # Maps filter keys to display info.
    FILTER_META = {
      tfidf: { letter: "A", label: "TF-IDF", score_label: "score" },
    }.freeze

    DEFAULT_TIMEOUT_S = 10

    # @param filters [Hash{Symbol => ToolFilter}] e.g. {tfidf: tfidf_filter}
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

      if active.size >= 1
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
      labels.first
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

      if AIA.debug?
        display_filter_results(key, scored)
        display_timing_table({ key => filter_ms[:ms] })
      end

      names = scored.map { |e| e[:name] }
      names.empty? ? nil : names
    rescue => e
      AIA.logger.debug "ToolFilterStrategy: #{meta_for(key)[:label]} filter failed: #{e.message}" if AIA.debug?
      nil
    end

    # Run a filter and return {scored:, ms:}.
    def run_filter_timed(_key, filter, prompt)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      scored = filter.filter_with_scores(prompt)
      ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
      { scored: scored, ms: ms }
    end

    # Display single-filter results via logger.
    def display_filter_results(key, scored)
      meta = meta_for(key)

      if scored.empty?
        AIA.logger.debug "[#{meta[:label]}] No tools matched (all tools available)"
        return
      end

      names = scored.map { |e| e[:name] }.join(', ')
      AIA.logger.debug "[#{meta[:label]}] Tools for this turn (#{scored.size}): #{names}"

      scored.each do |entry|
        AIA.logger.debug "[#{meta[:label]}]   #{entry[:name]}  (#{meta[:score_label]}: #{format('%.4f', entry[:score])})"
      end
    end

    # Print the timing table via logger.
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

      lines = []
      lines << "┌─#{'─' * pw}─" + columns.each_with_index.map { |_, i| "┬─#{'─' * widths[i]}─" }.join + "┐"
      lines << "│ #{'Process'.ljust(pw)} " + columns.each_with_index.map { |col, i| "│ #{col[:header].ljust(widths[i])} " }.join + "│"
      lines << "│ #{' ' * pw} " + columns.each_with_index.map { |col, i| "│ #{col[:sub].ljust(widths[i])} " }.join + "│"
      lines << "├─#{'─' * pw}─" + columns.each_with_index.map { |_, i| "┼─#{'─' * widths[i]}─" }.join + "┤"
      lines << "│ #{'prep'.ljust(pw)} " + columns.each_with_index.map { |col, i| "│ #{col[:prep].rjust(widths[i])} " }.join + "│"
      lines << "│ #{'filter'.ljust(pw)} " + columns.each_with_index.map { |col, i| "│ #{col[:filter].rjust(widths[i])} " }.join + "│"
      lines << "└─#{'─' * pw}─" + columns.each_with_index.map { |_, i| "┴─#{'─' * widths[i]}─" }.join + "┘"
      lines.each { |line| AIA.logger.debug line }
    end

    def fmt_ms(ms)
      "#{ms.round(1)}ms"
    end
  end
end
