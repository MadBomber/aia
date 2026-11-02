# lib/aia/timing.rb

module AIA
  # Monotonic-clock instrumentation shared by benchmark-reporting code.
  module Timing
    module_function

    # Run the block and return [result, elapsed_seconds].
    def timed
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      [result, Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0]
    end
  end
end
