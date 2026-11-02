# frozen_string_literal: true

# test/aia/model_registry_test.rb

require_relative '../test_helper'

class ModelRegistryTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('aia_registry')
    @path = File.join(@dir, 'models.json')
    @saved_file = RubyLLM.config.model_registry_file
  end

  def teardown
    RubyLLM.config.model_registry_file = @saved_file
    FileUtils.rm_rf(@dir)
  end

  def config(refresh: 7, aia_dir: @dir)
    OpenStruct.new(paths: OpenStruct.new(aia_dir: aia_dir), registry: OpenStruct.new(refresh: refresh))
  end

  def test_registry_path
    assert_equal File.join(File.expand_path('~/.config/aia'), 'models.json'),
                 AIA::ModelRegistry.registry_path('~/.config/aia')
    assert_nil AIA::ModelRegistry.registry_path(nil)
    assert_nil AIA::ModelRegistry.registry_path(' ')
  end

  def test_refresh_days
    assert_equal 7, AIA::ModelRegistry.refresh_days(nil)
    assert_equal 3, AIA::ModelRegistry.refresh_days('3')
    assert_equal 0, AIA::ModelRegistry.refresh_days(0)
    assert_equal 0, AIA::ModelRegistry.refresh_days(-2)
    assert_equal 7, AIA::ModelRegistry.refresh_days('weekly')
  end

  def test_refresh_due_when_the_file_is_missing
    assert AIA::ModelRegistry.refresh_due?(@path, 7)
  end

  def test_refresh_never_due_when_disabled
    refute AIA::ModelRegistry.refresh_due?(@path, 0)
  end

  def test_refresh_due_only_after_the_interval
    File.write(@path, '[]')
    written = File.mtime(@path).to_date

    refute AIA::ModelRegistry.refresh_due?(@path, 7, today: written + 7)
    assert AIA::ModelRegistry.refresh_due?(@path, 7, today: written + 8)
  end

  def test_prepare_refreshes_into_the_aia_dir_when_due
    AIA::ModelRegistry.expects(:refresh).with(@path)
    AIA::ModelRegistry.expects(:use).never

    AIA::ModelRegistry.prepare(config)
  end

  def test_prepare_uses_a_fresh_local_file
    File.write(@path, '[]')
    AIA::ModelRegistry.expects(:refresh).never
    AIA::ModelRegistry.expects(:use).with(@path)

    AIA::ModelRegistry.prepare(config)
  end

  def test_prepare_with_refresh_off_and_no_file_leaves_rubyllm_alone
    AIA::ModelRegistry.expects(:refresh).never
    AIA::ModelRegistry.expects(:use).never

    AIA::ModelRegistry.prepare(config(refresh: 0))
  end

  def test_prepare_without_an_aia_dir_does_nothing
    AIA::ModelRegistry.expects(:refresh).never
    AIA::ModelRegistry.expects(:use).never

    AIA::ModelRegistry.prepare(config(aia_dir: nil))
  end

  def test_refresh_saves_to_the_local_file
    AIA::Speech.stubs(:run_with_spinner).yields
    RubyLLM.models.expects(:refresh).with { RubyLLM.config.model_registry_file == @path }

    AIA::ModelRegistry.refresh(@path)

    assert_equal @path, RubyLLM.config.model_registry_file
  end

  def test_refresh_failure_keeps_the_previous_registry
    AIA::Speech.stubs(:run_with_spinner).raises(StandardError, 'offline')

    _, err = capture_io { AIA::ModelRegistry.refresh(@path) }

    assert_equal @saved_file, RubyLLM.config.model_registry_file
    assert_includes err, 'offline'
  end

  def test_use_loads_the_file
    RubyLLM.models.expects(:load_from_json).with(@path)

    AIA::ModelRegistry.use(@path)

    assert_equal @path, RubyLLM.config.model_registry_file
  end
end

class RemovedConfigKeysTest < Minitest::Test
  def test_an_old_config_file_with_removed_keys_still_loads
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'old.yml')
      File.write(path, <<~YAML)
        flags:
          clear: true
          expert_routing: true
          tool_filter_load: true
        output:
          markdown: false
        embedding:
          model: text-embedding-ada-002
        roles:
          dir: ~/.prompts/roles
        prompts:
          roles_dir: ~/.prompts/roles
          tools_prefix: tools
        llm:
          temperature: 0.3
      YAML

      config = AIA::Config.new(overrides: { extra_config_file: path })

      assert_in_delta 0.3, config.llm.temperature
      refute_respond_to config, :embedding
    end
  end
end
