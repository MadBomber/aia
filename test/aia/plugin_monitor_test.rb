# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'ostruct'
require 'stringio'

class PluginMonitorTest < Minitest::Test
  # Records loader calls instead of touching the running process, so monitor
  # behavior can be verified in isolation.
  class FakeLoader
    attr_reader :loaded, :unloaded

    def initialize
      @loaded   = []
      @unloaded = []
    end

    def load_file(path, _config = nil)
      @loaded << path
      File.basename(path, '.rb')
    end

    def unload_file(name, _config = nil)
      @unloaded << name
      name
    end
  end

  def setup
    @tmpdir  = Dir.mktmpdir('aia_pmon', TEST_TMPDIR)
    @config  = OpenStruct.new(paths: OpenStruct.new(plugins_dir: @tmpdir), loaded_plugins: [])
    @loader  = FakeLoader.new
    @monitor = AIA::PluginMonitor.new(@config, loader: @loader, interval: 0.05, output: StringIO.new)
  end

  def teardown
    @monitor.stop
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    super
  end

  # --- detect_changes (pure) ---

  def test_detect_changes_classifies_added_and_modified
    s1 = [Time.at(1), 1]
    s2 = [Time.at(2), 2]
    old = { 'a' => s1, 'b' => s1 }
    new = { 'a' => s1, 'b' => s2, 'c' => s1 }

    changes = @monitor.detect_changes(old, new)

    assert_includes changes, [:added, 'c']
    assert_includes changes, [:modified, 'b']
    refute(changes.any? { |event, _| event == :removed })
  end

  def test_detect_changes_classifies_removed
    s1 = [Time.at(1), 1]
    changes = @monitor.detect_changes({ 'a' => s1, 'b' => s1 }, { 'a' => s1 })

    assert_includes changes, [:removed, 'b']
  end

  # --- tick (scan + react) ---

  def test_tick_loads_a_new_file
    path = write_plugin('foo.rb', "x = 1\n")

    changes = @monitor.tick

    assert_includes changes, [:added, path]
    assert_includes @loader.loaded, path
  end

  def test_tick_reloads_a_modified_file
    path = write_plugin('foo.rb', "x = 1\n")
    @monitor.tick # register the file
    write_plugin('foo.rb', "x = 222222\n") # different size => signature changes

    changes = @monitor.tick

    assert_includes changes, [:modified, path]
    assert_equal 2, @loader.loaded.count(path) # loaded on add, again on modify
  end

  def test_tick_unloads_a_deleted_file
    path = write_plugin('foo.rb', "x = 1\n")
    @monitor.tick
    File.delete(path)

    changes = @monitor.tick

    assert_includes changes, [:removed, path]
    assert_includes @loader.unloaded, 'foo'
  end

  def test_tick_is_quiet_when_nothing_changes
    write_plugin('foo.rb', "x = 1\n")
    @monitor.tick

    assert_empty @monitor.tick
  end

  # --- listen backend ---

  def test_handle_listen_events_dispatches_by_type
    added    = [File.join(@tmpdir, 'a.rb')]
    modified = [File.join(@tmpdir, 'b.rb')]
    removed  = [File.join(@tmpdir, 'c.rb')]

    @monitor.send(:handle_listen_events, modified, added, removed)

    assert_includes @loader.loaded, added.first
    assert_includes @loader.loaded, modified.first
    assert_includes @loader.unloaded, 'c'
  end

  def test_handle_listen_events_ignores_nested_files
    nested = File.join(@tmpdir, 'sub', 'deep.rb')

    @monitor.send(:handle_listen_events, [], [nested], [])

    assert_empty @loader.loaded
  end

  def test_start_prefers_listen_when_available
    @monitor.stubs(:start_listen).returns(true)

    @monitor.start

    assert @monitor.running?
    assert_equal :listen, @monitor.backend
  end

  def test_start_falls_back_to_polling_when_listen_unavailable
    @monitor.stubs(:start_listen).returns(false)

    @monitor.start

    assert @monitor.running?
    assert_equal :polling, @monitor.backend
  end

  # --- lifecycle ---

  def test_start_then_stop
    @monitor.stubs(:start_listen).returns(false) # exercise the polling thread
    @monitor.start
    assert @monitor.running?

    @monitor.stop
    refute @monitor.running?
    assert_nil @monitor.backend
  end

  def test_start_is_noop_when_directory_absent
    config  = OpenStruct.new(paths: OpenStruct.new(plugins_dir: File.join(@tmpdir, 'nope')))
    monitor = AIA::PluginMonitor.new(config, loader: @loader)

    monitor.start

    refute monitor.running?
  end

  private

  def write_plugin(name, body)
    path = File.join(@tmpdir, name)
    File.write(path, body)
    path
  end
end
