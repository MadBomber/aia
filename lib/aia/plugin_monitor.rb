# frozen_string_literal: true

require_relative 'plugin_loader'

module AIA
  # Watches the plugins directory and keeps the running process in sync with it:
  #
  #   - a new `*.rb` file        -> loaded
  #   - an existing file changed -> reloaded (old definitions removed first)
  #   - a file removed           -> its definitions removed from the process
  #
  # Detection prefers the `listen` gem (native OS file events; instant, no idle
  # CPU). If `listen` cannot be loaded, it falls back to a background thread that
  # polls file signatures ([mtime, size]). Either way the same #react logic drives
  # {PluginLoader}, so behavior is identical — only latency differs.
  # :reek:TooManyInstanceVariables -- holds both backends' state (listener vs polling thread) plus watch config and callbacks
  class PluginMonitor
    DEFAULT_INTERVAL = 1.0 # seconds (polling fallback only)

    # @param config [#paths] provides paths.plugins_dir
    # @param loader [#load_file, #unload_file] plugin loader (default PluginLoader)
    # @param interval [Float] seconds between scans (polling fallback only)
    # @param output [IO] where status messages go (default $stderr)
    def initialize(config, loader: PluginLoader, interval: DEFAULT_INTERVAL, output: $stderr)
      @config   = config
      @loader   = loader
      @interval = interval
      @output   = output
      @dir      = config.paths&.plugins_dir
      @thread   = nil
      @listener = nil
      @running  = false
      @backend  = nil
      @snapshot = {}
    end

    # Start watching. Prefers listen; falls back to polling. No-op if the
    # directory is not watchable or the monitor is already running.
    #
    # @return [self]
    def start
      return self unless watchable?
      return self if @running

      @snapshot = current_snapshot
      @running  = true
      @backend  = start_listen ? :listen : start_polling
      self
    end

    # Stop watching, whichever backend is active.
    #
    # @return [self]
    def stop
      @running = false
      stop_listen
      stop_polling
      @backend = nil
      self
    end

    # @return [Boolean]
    def running?
      @running
    end

    # @return [Symbol, nil] :listen or :polling once started
    attr_reader :backend

    # Perform one scan-and-react cycle (polling backend). Compares the current
    # directory state to the previous snapshot, applies each change, then stores
    # the new snapshot. Public so it can be driven directly in tests.
    #
    # @return [Array<Array(Symbol, String)>] the changes applied this tick
    def tick
      now     = current_snapshot
      changes = detect_changes(@snapshot, now)
      changes.each { |event, path| react(event, path) }
      @snapshot = now
      changes
    end

    # Compare two `path => signature` snapshots and classify the differences.
    #
    # @return [Array<Array(Symbol, String)>] e.g. [[:added, "/p/foo.rb"], ...]
    def detect_changes(old_snapshot, new_snapshot)
      old_keys = old_snapshot.keys
      new_keys = new_snapshot.keys
      added   = (new_keys - old_keys).map { |path| [:added, path] }
      removed = (old_keys - new_keys).map { |path| [:removed, path] }
      modified = (old_keys & new_keys)
                 .reject { |path| new_snapshot[path] == old_snapshot[path] }
                 .map { |path| [:modified, path] }
      added + removed + modified
    end

    private

    def watchable?
      !@dir.nil? && !@dir.to_s.strip.empty? && Dir.exist?(@dir)
    end

    # --- listen backend ---

    # Try to start the listen-based watcher. Returns true on success, false if
    # the listen gem is unavailable (caller then uses the polling fallback).
    def start_listen
      require 'listen'
      @listener = Listen.to(@dir, only: /\.rb$/) do |modified, added, removed|
        handle_listen_events(modified, added, removed)
      end
      @listener.start
      true
    rescue LoadError
      false
    end

    # Map a listen callback into per-file reactions, ignoring anything that is
    # not a top-level file of the plugins directory (listen watches recursively).
    def handle_listen_events(modified, added, removed)
      { added: added, modified: modified, removed: removed }.each do |event, paths|
        Array(paths).each { |path| react(event, path) if top_level?(path) }
      end
    end

    # listen reports resolved (symlink-free) paths, and on macOS the plugins
    # dir is often reached via a symlink (e.g. /tmp -> /private/tmp). Compare
    # canonicalized directories so the top-level filter matches correctly.
    def top_level?(path)
      canonical_dir(File.dirname(path)) == watched_dir
    end

    def watched_dir
      @watched_dir ||= canonical_dir(@dir)
    end

    def canonical_dir(dir)
      File.realpath(dir)
    rescue StandardError
      File.expand_path(dir)
    end

    def stop_listen
      @listener&.stop
    rescue StandardError
      # best-effort
    ensure
      @listener = nil
    end

    # --- polling backend ---

    def start_polling
      @thread = Thread.new { watch_loop }
      @thread.name = 'aia-plugin-monitor' if @thread.respond_to?(:name=)
      :polling
    end

    def stop_polling
      begin
        @thread&.wakeup
      rescue ThreadError
        # thread already finished
      end
      @thread&.join(@interval + 0.5)
      @thread = nil
    end

    def watch_loop
      while @running
        begin
          tick
        rescue StandardError => e
          @output.puts "Plugin monitor error: #{e.message}"
        end
        sleep @interval
      end
    end

    # --- shared ---

    # @return [Hash{String=>Array}] path => [mtime, size]
    def current_snapshot
      Dir.glob(File.join(@dir, '*.rb')).to_h { |path| [path, file_signature(path)] }
    end

    def file_signature(path)
      stat = File.stat(path)
      [stat.mtime, stat.size]
    rescue SystemCallError
      nil
    end

    # Apply a single change by driving the loader, and report it.
    def react(event, path)
      name = File.basename(path, '.rb')
      case event
      when :added
        announce('loaded', name) if @loader.load_file(path, @config)
      when :modified
        announce('reloaded', name) if @loader.load_file(path, @config)
      when :removed
        announce('unloaded', name) if @loader.unload_file(name, @config)
      end
    end

    def announce(action, name)
      @output.puts "Plugin #{action}: #{name}"
    end
  end
end
