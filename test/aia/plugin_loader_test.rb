# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'ostruct'

class PluginLoaderTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('aia_plugins', TEST_TMPDIR)
    @config = OpenStruct.new(
      paths: OpenStruct.new(plugins_dir: @tmpdir),
      loaded_plugins: []
    )
  end

  def teardown
    AIA::PluginLoader.reset!(@config)
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    super
  end

  def test_loads_only_top_level_rb_files_and_tracks_basenames
    File.write(File.join(@tmpdir, 'alpha.rb'), "AIA_TEST_PLUGIN_ALPHA = true\n")
    File.write(File.join(@tmpdir, 'beta_plugin.rb'), "AIA_TEST_PLUGIN_BETA = true\n")

    nested_dir = File.join(@tmpdir, 'nested')
    Dir.mkdir(nested_dir)
    File.write(File.join(nested_dir, 'ignored.rb'), "AIA_TEST_PLUGIN_IGNORED = true\n")

    loaded = AIA::PluginLoader.load!(@config)

    assert_equal %w[alpha beta_plugin], loaded
    assert_equal %w[alpha beta_plugin], @config.loaded_plugins
    assert defined?(AIA_TEST_PLUGIN_ALPHA)
    assert defined?(AIA_TEST_PLUGIN_BETA)
    refute defined?(AIA_TEST_PLUGIN_IGNORED)
  ensure
    Object.send(:remove_const, :AIA_TEST_PLUGIN_ALPHA) if defined?(AIA_TEST_PLUGIN_ALPHA)
    Object.send(:remove_const, :AIA_TEST_PLUGIN_BETA) if defined?(AIA_TEST_PLUGIN_BETA)
    Object.send(:remove_const, :AIA_TEST_PLUGIN_IGNORED) if defined?(AIA_TEST_PLUGIN_IGNORED)
  end

  def test_returns_empty_when_plugins_dir_not_configured
    @config.paths.plugins_dir = nil

    assert_equal [], AIA::PluginLoader.load!(@config)
    assert_equal [], @config.loaded_plugins
  end

  def test_returns_empty_when_plugins_dir_missing
    @config.paths.plugins_dir = File.join(@tmpdir, 'missing')

    assert_equal [], AIA::PluginLoader.load!(@config)
    assert_equal [], @config.loaded_plugins
  end

  def test_load_file_defines_method_and_tracks_basename
    path = File.join(@tmpdir, 'greeter.rb')
    File.write(path, "def aia_test_greet; :hi; end\n")

    name = AIA::PluginLoader.load_file(path, @config)

    assert_equal 'greeter', name
    assert_includes Object.private_instance_methods(false), :aia_test_greet
    assert_includes @config.loaded_plugins, 'greeter'
  end

  def test_unload_file_removes_defined_method
    path = File.join(@tmpdir, 'greeter.rb')
    File.write(path, "def aia_test_greet; :hi; end\n")
    AIA::PluginLoader.load_file(path, @config)

    assert_equal 'greeter', AIA::PluginLoader.unload_file('greeter', @config)

    refute_includes Object.private_instance_methods(false), :aia_test_greet
    refute_includes Array(@config.loaded_plugins), 'greeter'
  end

  def test_unload_file_unknown_plugin_returns_nil
    assert_nil AIA::PluginLoader.unload_file('does_not_exist', @config)
  end

  def test_reload_reflects_updated_body
    path = File.join(@tmpdir, 'greeter.rb')
    File.write(path, "def aia_test_greet; :v1; end\n")
    AIA::PluginLoader.load_file(path, @config)

    File.write(path, "def aia_test_greet; :v2; end\n")
    AIA::PluginLoader.load_file(path, @config)

    assert_equal :v2, Object.new.send(:aia_test_greet)
  end

  def test_reload_drops_methods_no_longer_defined
    path = File.join(@tmpdir, 'multi.rb')
    File.write(path, "def aia_test_a; end\ndef aia_test_b; end\n")
    AIA::PluginLoader.load_file(path, @config)
    assert_includes Object.private_instance_methods(false), :aia_test_b

    File.write(path, "def aia_test_a; end\n") # b removed from the file
    AIA::PluginLoader.load_file(path, @config)

    assert_includes Object.private_instance_methods(false), :aia_test_a
    refute_includes Object.private_instance_methods(false), :aia_test_b
  end

  def test_load_file_failure_returns_nil_and_does_not_track
    path = File.join(@tmpdir, 'broken.rb')
    File.write(path, "def oops; \n") # syntax error

    _out, err = capture_io { @result = AIA::PluginLoader.load_file(path, @config) }

    assert_nil @result
    refute_includes Array(@config.loaded_plugins), 'broken'
    assert_match(/Failed to load plugin/, err)
  end
end
