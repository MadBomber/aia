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
end
