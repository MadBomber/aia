# frozen_string_literal: true

# lib/aia/tool_filter_strategy.rb
#
# Strategy resolver for A/B testing tool filtering approaches.
# Reads AIA.config.flags.tool_filter_a and tool_filter_b to decide
# which tool list to pass to the streaming runner:
#   A only  -> KBS rule-based filtering (reads AIA.turn_state.active_tools)
#   B only  -> TF-IDF similarity-based filtering
#   A and B -> comparison mode with side-by-side display
#
# After each resolve(), prints a timing comparison table showing
# prep and filter times for both Option A (KBS) and Option B (TF-IDF).

module AIA
  class ToolFilterStrategy
    # @param tfidf_filter [TfidfToolFilter, nil] pre-built TF-IDF filter (nil when B is disabled)
    # @param ui_presenter [UIPresenter] for comparison mode display
    # @param kbs_prep_ms [Float] KBS initialization time in milliseconds
    # @param tfidf_prep_ms [Float] TF-IDF initialization time in milliseconds
    def initialize(tfidf_filter: nil, ui_presenter: nil,
                   kbs_prep_ms: 0.0, tfidf_prep_ms: 0.0)
      @tfidf_filter  = tfidf_filter
      @ui_presenter  = ui_presenter
      @kbs_prep_ms   = kbs_prep_ms
      @tfidf_prep_ms = tfidf_prep_ms
    end

    # Resolve the tool list for this turn based on the active strategy.
    # Also accepts the KBS per-turn evaluation time so it can be shown
    # alongside the TF-IDF filter time in the comparison table.
    #
    # @param prompt [String] the user's processed prompt
    # @param kbs_turn_ms [Float] time spent on KBS evaluate_turn + apply (milliseconds)
    # @return [Array<String>, nil] tool names to allow, or nil for all tools
    def resolve(prompt, kbs_turn_ms: 0.0)
      use_a = AIA.config.flags.tool_filter_a
      use_b = AIA.config.flags.tool_filter_b

      if use_a && use_b && @tfidf_filter
        resolve_comparison(prompt, kbs_turn_ms)
      elsif use_b && @tfidf_filter
        resolve_tfidf(prompt, kbs_turn_ms)
      else
        resolve_kbs(kbs_turn_ms)
      end
    end

    # @return [String] label for the active strategy (used in debug logging)
    def active_strategy_label
      use_a = AIA.config.flags.tool_filter_a
      use_b = AIA.config.flags.tool_filter_b

      if use_a && use_b
        "A+B comparison"
      elsif use_b
        "B (TF-IDF)"
      else
        "A (KBS)"
      end
    end

    private

    # Option A: read KBS-filtered tool names from turn state
    def resolve_kbs(kbs_turn_ms)
      tools = AIA.turn_state&.active_tools
      display_timing_table(kbs_filter_ms: kbs_turn_ms, tfidf_filter_ms: nil)
      tools
    end

    # Option B: TF-IDF similarity filtering
    def resolve_tfidf(prompt, kbs_turn_ms)
      tfidf_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      scored = @tfidf_filter.filter_with_scores(prompt)
      tfidf_filter_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - tfidf_start) * 1000

      display_tfidf_results(scored)
      display_timing_table(kbs_filter_ms: kbs_turn_ms, tfidf_filter_ms: tfidf_filter_ms)

      names = scored.map { |e| e[:name] }
      names.empty? ? nil : names
    end

    # Display TF-IDF filtering results to $stderr, matching the KBS output style.
    def display_tfidf_results(scored)
      if scored.empty?
        $stderr.puts "\n[TF-IDF] No tools matched (all tools available)"
        return
      end

      names = scored.map { |e| e[:name] }.join(', ')
      $stderr.puts "\n[TF-IDF] Tools for this turn (#{scored.size}): #{names}"

      scored.each do |entry|
        $stderr.puts "[TF-IDF]   #{entry[:name]}  (score: #{format('%.4f', entry[:score])})"
      end
    end

    # Comparison mode: run both, display side-by-side, ask user to pick
    def resolve_comparison(prompt, kbs_turn_ms)
      kbs_tools = AIA.turn_state&.active_tools || []

      tfidf_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      tfidf_scored = @tfidf_filter.filter_with_scores(prompt)
      tfidf_filter_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - tfidf_start) * 1000

      tfidf_tools = tfidf_scored.map { |e| e[:name] }

      display_comparison(kbs_tools, tfidf_scored)
      display_timing_table(kbs_filter_ms: kbs_turn_ms, tfidf_filter_ms: tfidf_filter_ms)

      choice = prompt_user_choice
      case choice
      when "a"
        kbs_tools.empty? ? nil : kbs_tools
      when "b"
        tfidf_tools.empty? ? nil : tfidf_tools
      when "m"
        merged = (kbs_tools + tfidf_tools).uniq
        merged.empty? ? nil : merged
      else
        kbs_tools.empty? ? nil : kbs_tools
      end
    end

    # Print the timing comparison table to $stderr.
    #
    # ┌─────────┬──────────────┬────────────────┐
    # │ Process │ Option A     │ Option B       │
    # │         │ (KBS)        │ (TF-IDF)       │
    # ├─────────┼──────────────┼────────────────┤
    # │ prep    │   12.3ms     │     8.2ms      │
    # │ filter  │    3.1ms     │     1.8ms      │
    # └─────────┴──────────────┴────────────────┘
    def display_timing_table(kbs_filter_ms:, tfidf_filter_ms:)
      col_a = fmt_ms(@kbs_prep_ms)
      col_b = tfidf_filter_ms ? fmt_ms(@tfidf_prep_ms) : "--"
      filter_a = fmt_ms(kbs_filter_ms)
      filter_b = tfidf_filter_ms ? fmt_ms(tfidf_filter_ms) : "--"

      # Column widths
      pw = 7   # "Process" header is 7, "filter" is 6
      aw = [10, col_a.length, filter_a.length].max
      bw = [10, col_b.length, filter_b.length].max

      $stderr.puts
      $stderr.puts "┌─#{'─' * pw}─┬─#{'─' * aw}─┬─#{'─' * bw}─┐"
      $stderr.puts "│ #{'Process'.ljust(pw)} │ #{'Option A'.ljust(aw)} │ #{'Option B'.ljust(bw)} │"
      $stderr.puts "│ #{' ' * pw} │ #{'(KBS)'.ljust(aw)} │ #{'(TF-IDF)'.ljust(bw)} │"
      $stderr.puts "├─#{'─' * pw}─┼─#{'─' * aw}─┼─#{'─' * bw}─┤"
      $stderr.puts "│ #{'prep'.ljust(pw)} │ #{col_a.rjust(aw)} │ #{col_b.rjust(bw)} │"
      $stderr.puts "│ #{'filter'.ljust(pw)} │ #{filter_a.rjust(aw)} │ #{filter_b.rjust(bw)} │"
      $stderr.puts "└─#{'─' * pw}─┴─#{'─' * aw}─┴─#{'─' * bw}─┘"
    end

    def display_comparison(kbs_tools, tfidf_scored)
      $stderr.puts "\n#{'=' * 60}"
      $stderr.puts "  Tool Filter Comparison (A/B Test)"
      $stderr.puts "#{'=' * 60}"

      $stderr.puts "\n  [A] KBS Rule-Based (#{kbs_tools.size} tools):"
      if kbs_tools.empty?
        $stderr.puts "      (none — all tools available)"
      else
        kbs_tools.each { |t| $stderr.puts "      - #{t}" }
      end

      $stderr.puts "\n  [B] TF-IDF Similarity (#{tfidf_scored.size} tools):"
      if tfidf_scored.empty?
        $stderr.puts "      (none matched threshold)"
      else
        tfidf_scored.each do |entry|
          $stderr.puts "      - #{entry[:name]}  (score: #{format('%.4f', entry[:score])})"
        end
      end

      # Show overlap
      tfidf_names = tfidf_scored.map { |e| e[:name] }
      overlap = kbs_tools & tfidf_names
      only_a  = kbs_tools - tfidf_names
      only_b  = tfidf_names - kbs_tools

      $stderr.puts "\n  Overlap: #{overlap.size}  |  Only A: #{only_a.size}  |  Only B: #{only_b.size}"
      $stderr.puts "#{'=' * 60}"
    end

    def prompt_user_choice
      $stderr.print "  Choose: [A]KBS / [B]TF-IDF / [M]erge (default: A): "
      input = $stdin.gets
      return "a" if input.nil?
      input.strip.downcase[0] || "a"
    rescue StandardError
      "a"
    end

    def fmt_ms(ms)
      "#{ms.round(1)}ms"
    end
  end
end
