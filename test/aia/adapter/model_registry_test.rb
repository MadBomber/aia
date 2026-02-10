# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'
require 'fileutils'

class ModelRegistryTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('aia_test_registry')
    @registry = AIA::Adapter::ModelRegistry.new

    AIA.stubs(:config).returns(OpenStruct.new(
      paths: OpenStruct.new(aia_dir: @tmpdir),
      registry: OpenStruct.new(refresh: 7)
    ))
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    super
  end

  def test_class_exists
    assert_kind_of Class, AIA::Adapter::ModelRegistry
  end

  # --- models_json_path ---

  def test_models_json_path_returns_correct_path
    expected = File.join(@tmpdir, 'models.json')
    assert_equal expected, @registry.models_json_path
  end

  def test_models_json_path_returns_nil_when_no_aia_dir
    AIA.stubs(:config).returns(OpenStruct.new(
      paths: OpenStruct.new(aia_dir: nil)
    ))

    assert_nil @registry.models_json_path
  end

  def test_models_json_path_returns_nil_when_paths_nil
    AIA.stubs(:config).returns(OpenStruct.new(paths: nil))

    assert_nil @registry.models_json_path
  end

  # --- models_last_refresh ---

  def test_models_last_refresh_returns_nil_when_no_file
    assert_nil @registry.models_last_refresh
  end

  def test_models_last_refresh_returns_date_from_mtime
    path = @registry.models_json_path
    File.write(path, '[]')

    result = @registry.models_last_refresh
    assert_kind_of Date, result
    assert_equal Date.today, result
  end

  def test_models_last_refresh_returns_nil_when_path_nil
    AIA.stubs(:config).returns(OpenStruct.new(
      paths: OpenStruct.new(aia_dir: nil)
    ))

    assert_nil @registry.models_last_refresh
  end

  # --- save_models_to_json ---

  def test_save_models_to_json_writes_file
    mock_model = mock('model')
    mock_model.stubs(:to_h).returns({ id: 'gpt-4o', name: 'GPT-4o' })

    mock_models = mock('models')
    mock_models.stubs(:all).returns([mock_model])
    RubyLLM.stubs(:models).returns(mock_models)

    @registry.save_models_to_json

    assert File.exist?(@registry.models_json_path)
    data = JSON.parse(File.read(@registry.models_json_path))
    assert_kind_of Array, data
    assert_equal 1, data.size
  end

  def test_save_models_to_json_returns_nil_when_no_path
    AIA.stubs(:config).returns(OpenStruct.new(
      paths: OpenStruct.new(aia_dir: nil)
    ))

    # Should not raise
    @registry.save_models_to_json
  end

  # --- copy_bundled_models_to_local ---

  def test_copy_bundled_models_to_local_copies_file
    # Create a fake bundled models file
    bundled_dir = Dir.mktmpdir('bundled')
    bundled_path = File.join(bundled_dir, 'models.json')
    File.write(bundled_path, '[{"id":"bundled-model"}]')

    mock_config = mock('rubyllm_config')
    mock_config.stubs(:model_registry_file).returns(bundled_path)
    RubyLLM.stubs(:config).returns(mock_config)

    @registry.copy_bundled_models_to_local

    assert File.exist?(@registry.models_json_path)
    content = File.read(@registry.models_json_path)
    assert_includes content, 'bundled-model'
  ensure
    FileUtils.rm_rf(bundled_dir)
  end

  def test_copy_bundled_models_falls_back_to_save
    mock_config = mock('rubyllm_config')
    mock_config.stubs(:model_registry_file).returns('/nonexistent/path')
    RubyLLM.stubs(:config).returns(mock_config)

    # When bundled file doesn't exist, should call save_models_to_json
    @registry.expects(:save_models_to_json).once

    @registry.copy_bundled_models_to_local
  end

  # --- refresh ---

  def test_refresh_skips_when_no_aia_dir
    AIA.stubs(:config).returns(OpenStruct.new(
      paths: OpenStruct.new(aia_dir: nil)
    ))

    # Should not call any RubyLLM methods
    RubyLLM.expects(:config).never

    @registry.refresh
  end

  def test_refresh_skips_when_refresh_days_is_zero
    AIA.stubs(:config).returns(OpenStruct.new(
      paths: OpenStruct.new(aia_dir: @tmpdir),
      registry: OpenStruct.new(refresh: 0)
    ))

    # Write a models file so copy_bundled isn't called
    File.write(File.join(@tmpdir, 'models.json'), '[]')

    mock_config = mock('rubyllm_config')
    mock_config.stubs(:model_registry_file=)
    RubyLLM.stubs(:config).returns(mock_config)

    # refresh! should NOT be called when refresh_days is 0
    mock_models = mock('models')
    mock_models.expects(:refresh!).never
    RubyLLM.stubs(:models).returns(mock_models)

    @registry.refresh
  end

  def test_refresh_skips_when_recently_refreshed
    AIA.stubs(:config).returns(OpenStruct.new(
      paths: OpenStruct.new(aia_dir: @tmpdir),
      registry: OpenStruct.new(refresh: 7)
    ))

    # Write a models file with today's mtime
    File.write(File.join(@tmpdir, 'models.json'), '[]')

    mock_config = mock('rubyllm_config')
    mock_config.stubs(:model_registry_file=)
    RubyLLM.stubs(:config).returns(mock_config)

    # Should not refresh because last_refresh is today
    mock_models = mock('models')
    mock_models.expects(:refresh!).never
    RubyLLM.stubs(:models).returns(mock_models)

    @registry.refresh
  end
end
