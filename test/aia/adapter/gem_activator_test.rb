# frozen_string_literal: true

require_relative '../../test_helper'

class GemActivatorTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, AIA::Adapter::GemActivator
  end

  def test_responds_to_class_methods
    assert_respond_to AIA::Adapter::GemActivator, :activate_gem_for_require
    assert_respond_to AIA::Adapter::GemActivator, :find_gem_path
    assert_respond_to AIA::Adapter::GemActivator, :trigger_tool_loading
  end

  # --- activate_gem_for_require ---

  def test_activate_gem_for_require_returns_early_when_gem_activates
    Gem.stubs(:try_activate).with('some_gem').returns(true)

    # Should not call find_gem_path if try_activate succeeds
    AIA::Adapter::GemActivator.expects(:find_gem_path).never

    AIA::Adapter::GemActivator.activate_gem_for_require('some_gem')
  end

  def test_activate_gem_for_require_searches_gem_path_when_try_activate_fails
    Gem.stubs(:try_activate).with('missing_gem').returns(false)
    AIA::Adapter::GemActivator.stubs(:find_gem_path).with('missing_gem').returns(nil)

    # Should not raise even when gem is not found
    AIA::Adapter::GemActivator.activate_gem_for_require('missing_gem')
  end

  def test_activate_gem_for_require_adds_lib_to_load_path
    gem_path = '/fake/gems/my_gem-1.0.0'
    lib_path = '/fake/gems/my_gem-1.0.0/lib'

    Gem.stubs(:try_activate).with('my_gem').returns(false)
    AIA::Adapter::GemActivator.stubs(:find_gem_path).with('my_gem').returns(gem_path)

    # Remove the path if it's already there
    $LOAD_PATH.delete(lib_path)

    AIA::Adapter::GemActivator.activate_gem_for_require('my_gem')

    assert_includes $LOAD_PATH, lib_path
  ensure
    $LOAD_PATH.delete(lib_path)
  end

  def test_activate_gem_for_require_does_not_duplicate_load_path
    gem_path = '/fake/gems/dup_gem-2.0.0'
    lib_path = '/fake/gems/dup_gem-2.0.0/lib'

    Gem.stubs(:try_activate).with('dup_gem').returns(false)
    AIA::Adapter::GemActivator.stubs(:find_gem_path).with('dup_gem').returns(gem_path)

    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    original_count = $LOAD_PATH.count(lib_path)

    AIA::Adapter::GemActivator.activate_gem_for_require('dup_gem')

    assert_equal original_count, $LOAD_PATH.count(lib_path)
  ensure
    $LOAD_PATH.delete(lib_path)
  end

  # --- find_gem_path ---

  def test_find_gem_path_returns_nil_when_no_gems_found
    Gem.stubs(:path).returns(['/nonexistent/path'])

    result = AIA::Adapter::GemActivator.find_gem_path('nonexistent_gem')
    assert_nil result
  end

  def test_find_gem_path_returns_latest_version
    Dir.mktmpdir do |tmpdir|
      gems_dir = File.join(tmpdir, 'gems')
      FileUtils.mkdir_p(File.join(gems_dir, 'test_gem-1.0.0'))
      FileUtils.mkdir_p(File.join(gems_dir, 'test_gem-2.0.0'))
      FileUtils.mkdir_p(File.join(gems_dir, 'test_gem-1.5.0'))

      Gem.stubs(:path).returns([tmpdir])

      result = AIA::Adapter::GemActivator.find_gem_path('test_gem')
      assert_equal File.join(gems_dir, 'test_gem-2.0.0'), result
    end
  end

  def test_find_gem_path_ignores_non_matching_gems
    Dir.mktmpdir do |tmpdir|
      gems_dir = File.join(tmpdir, 'gems')
      FileUtils.mkdir_p(File.join(gems_dir, 'test_gem-1.0.0'))
      FileUtils.mkdir_p(File.join(gems_dir, 'test_gem_extra-3.0.0'))

      Gem.stubs(:path).returns([tmpdir])

      result = AIA::Adapter::GemActivator.find_gem_path('test_gem')
      assert_equal File.join(gems_dir, 'test_gem-1.0.0'), result
    end
  end

  # --- trigger_tool_loading ---

  def test_trigger_tool_loading_calls_load_all_tools_if_available
    mock_mod = mock('module')
    mock_mod.expects(:load_all_tools).once
    mock_mod.stubs(:respond_to?).with(:load_all_tools).returns(true)

    Object.stubs(:const_get).with('SharedTools').returns(mock_mod)

    AIA::Adapter::GemActivator.trigger_tool_loading('shared_tools')
  end

  def test_trigger_tool_loading_calls_tools_if_no_load_all_tools
    mock_mod = mock('module')
    mock_mod.stubs(:respond_to?).with(:load_all_tools).returns(false)
    mock_mod.stubs(:respond_to?).with(:tools).returns(true)
    mock_mod.expects(:tools).once

    Object.stubs(:const_get).with('SharedTools').returns(mock_mod)

    AIA::Adapter::GemActivator.trigger_tool_loading('shared_tools')
  end

  def test_trigger_tool_loading_handles_missing_constant
    # Should not raise when the constant doesn't exist
    AIA::Adapter::GemActivator.trigger_tool_loading('totally_nonexistent_gem_xyz')
  end

  def test_trigger_tool_loading_converts_hyphenated_names
    mock_mod = mock('module')
    mock_mod.stubs(:respond_to?).with(:load_all_tools).returns(false)
    mock_mod.stubs(:respond_to?).with(:tools).returns(false)

    Object.stubs(:const_get).with('MyToolKit').returns(mock_mod)

    # Should not raise
    AIA::Adapter::GemActivator.trigger_tool_loading('my-tool-kit')
  end

  def teardown
    super
  end
end
