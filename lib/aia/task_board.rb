# frozen_string_literal: true

# lib/aia/task_board.rb
#
# The TrakFlow task board, started on first use. Nothing touches the disk
# until a feature that records tasks (/task, /delegate, /spawn tracking,
# --track-pipeline, the task-board tools) actually needs it, so a plain
# session leaves no .trak_flow directory behind.

require 'fileutils'

module AIA
  module TaskBoard
    module_function

    # Whether the trak_flow gem can be loaded.
    #
    # @return [Boolean]
    def gem_available?
      return true if defined?(TrakFlow)

      require 'trak_flow'
      true
    rescue LoadError
      false
    end

    # Make sure a TrakFlow project exists, creating .trak_flow in the current
    # directory when none is found here or in a parent. The tasks themselves
    # live in TrakFlow's database (~/.config/trak_flow/tf.db by default).
    #
    # @return [Boolean] true when the project is ready
    def ensure_project!
      return false unless gem_available?
      return true if TrakFlow.initialized?

      FileUtils.mkdir_p(TrakFlow.trak_flow_dir)
      TrakFlow::Storage::Database.new.connect
      TrakFlow.reset_root!
      TrakFlow.initialized?
    rescue StandardError => e
      AIA.debug_warn("TrakFlow initialization failed (non-fatal): #{e.message}", exc: e)
      false
    end

    # A TaskCoordinator on a ready project, or nil when TrakFlow can't run.
    #
    # @return [AIA::TaskCoordinator, nil]
    def coordinator
      return nil unless ensure_project!

      require_relative 'trakflow_bridge'
      require_relative 'task_coordinator'
      TaskCoordinator.new
    rescue StandardError => e
      AIA.debug_warn("TaskCoordinator initialization failed (non-fatal): #{e.message}", exc: e)
      nil
    end
  end
end
