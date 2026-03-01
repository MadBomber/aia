# frozen_string_literal: true

# lib/aia/tool_filter.rb
#
# Abstract base class for tool filtering strategies.
# Subclasses implement `do_prep` (one-time index build) and
# `do_filter_with_scores` (per-turn query). The base class provides
# timing instrumentation and a uniform public API.

module AIA
  class ToolFilter
    attr_reader :tool_count, :prep_ms, :label

    def initialize(label:, db_dir: nil, load_db: false, save_db: false)
      @label      = label
      @db_dir     = db_dir
      @load_db    = load_db
      @save_db    = save_db
      @tool_count = 0
      @prep_ms    = 0.0
    end

    # One-time initialization. Captures timing in @prep_ms, returns it.
    def prep
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      do_prep
      @prep_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
    end

    # Per-turn query. Returns [names] or nil (nil = all tools).
    def filter(prompt)
      names = filter_with_scores(prompt).map { |e| e[:name] }
      names.empty? ? nil : names
    end

    # Per-turn query with scores. Returns [{name:, score:}].
    def filter_with_scores(prompt)
      do_filter_with_scores(prompt)
    end

    # Override in subclasses that need resource cleanup.
    def cleanup; end

    # True when the filter has indexed at least one tool.
    def available?
      @tool_count > 0
    end

    # True when this filter supports database persistence (--load / --save).
    def persistable?
      false
    end

    protected

    def do_prep
      raise NotImplementedError, "#{self.class}#do_prep must be implemented"
    end

    def do_filter_with_scores(_prompt)
      raise NotImplementedError, "#{self.class}#do_filter_with_scores must be implemented"
    end
  end
end
