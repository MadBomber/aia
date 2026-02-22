# frozen_string_literal: true

require_relative '../test_helper'
require 'ostruct'
require 'tmpdir'

class PromptHandlerFetchPromptTest < Minitest::Test
  def setup
    @prompts_dir = Dir.mktmpdir
    @roles_dir = File.join(@prompts_dir, 'roles')
    Dir.mkdir(@roles_dir)

    AIA.stubs(:config).returns(OpenStruct.new(
      models: [OpenStruct.new(name: 'test-model')],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      pipeline: [],
      prompts: OpenStruct.new(
        dir: @prompts_dir,
        extname: '.md',
        roles_dir: @roles_dir,
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: nil
      ),
      prompt_id: 'test_prompt'
    ))

    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.rm_rf(@prompts_dir)
    super
  end

  def test_fetch_fuzzy_search_sentinel
    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    @handler.stubs(:fuzzy_search_prompt).with('').returns(mock_parsed)

    result = @handler.fetch_prompt('__FUZZY_SEARCH__')
    assert_equal mock_parsed, result
  end

  def test_fetch_executable_prompt_sentinel
    AIA.config.stubs(:executable_prompt_content).returns("puts 'hello'")

    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    PM.stubs(:parse).with("puts 'hello'").returns(mock_parsed)

    result = @handler.fetch_prompt('__EXECUTABLE_PROMPT__')
    assert_equal mock_parsed, result
  end

  def test_fetch_prompt_with_existing_file
    File.write(File.join(@prompts_dir, 'my_prompt.md'), '# My Prompt')

    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    PM.stubs(:parse).with('my_prompt').returns(mock_parsed)

    result = @handler.fetch_prompt('my_prompt')
    assert_equal mock_parsed, result
  end

  def test_fetch_prompt_missing_file_without_fuzzy
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.fetch_prompt('nonexistent')
    assert stderr_messages.any? { |m| m.include?('Could not find prompt') }
  end
end


class PromptHandlerFetchRoleTest < Minitest::Test
  def setup
    @prompts_dir = Dir.mktmpdir
    @roles_dir = File.join(@prompts_dir, 'roles')
    Dir.mkdir(@roles_dir)

    AIA.stubs(:config).returns(OpenStruct.new(
      models: [OpenStruct.new(name: 'test-model')],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      pipeline: [],
      prompts: OpenStruct.new(
        dir: @prompts_dir,
        extname: '.md',
        roles_dir: @roles_dir,
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: nil
      ),
      prompt_id: 'test_prompt'
    ))

    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.rm_rf(@prompts_dir)
    super
  end

  def test_fetch_role_nil_exits
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.fetch_role(nil)
    assert stderr_messages.any? { |m| m.include?('Role ID cannot be empty') }
  end

  def test_fetch_role_prepends_prefix
    File.write(File.join(@roles_dir, 'architect.md'), '# Architect Role')

    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    PM.stubs(:parse).with('roles/architect').returns(mock_parsed)

    result = @handler.fetch_role('architect')
    assert_equal mock_parsed, result
  end

  def test_fetch_role_already_prefixed
    File.write(File.join(@roles_dir, 'architect.md'), '# Architect Role')

    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    PM.stubs(:parse).with('roles/architect').returns(mock_parsed)

    result = @handler.fetch_role('roles/architect')
    assert_equal mock_parsed, result
  end

  def test_fetch_role_missing_without_fuzzy
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.fetch_role('nonexistent')
    assert stderr_messages.any? { |m| m.include?('Could not find role') }
  end
end


class PromptHandlerLoadRoleForModelTest < Minitest::Test
  def setup
    @prompts_dir = Dir.mktmpdir
    @roles_dir = File.join(@prompts_dir, 'roles')
    Dir.mkdir(@roles_dir)

    AIA.stubs(:config).returns(OpenStruct.new(
      models: [OpenStruct.new(name: 'test-model')],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      pipeline: [],
      prompts: OpenStruct.new(
        dir: @prompts_dir,
        extname: '.md',
        roles_dir: @roles_dir,
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: nil
      ),
      prompt_id: 'test_prompt'
    ))

    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.rm_rf(@prompts_dir)
    super
  end

  def test_load_role_from_model_spec_hash
    File.write(File.join(@roles_dir, 'coder.md'), '# Coder Role')

    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    mock_parsed.stubs(:to_s).returns('Coder Role Content')
    PM.stubs(:parse).with('roles/coder').returns(mock_parsed)

    result = @handler.load_role_for_model({ role: 'coder' })
    assert_equal 'Coder Role Content', result
  end

  def test_load_role_with_default_role
    File.write(File.join(@roles_dir, 'default.md'), '# Default')

    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    mock_parsed.stubs(:to_s).returns('Default Role')
    PM.stubs(:parse).with('roles/default').returns(mock_parsed)

    result = @handler.load_role_for_model({}, 'default')
    assert_equal 'Default Role', result
  end

  def test_load_role_nil_role_returns_nil
    result = @handler.load_role_for_model({ role: nil })
    assert_nil result
  end

  def test_load_role_empty_role_returns_nil
    result = @handler.load_role_for_model({ role: '' })
    assert_nil result
  end

  def test_load_role_non_hash_uses_default
    File.write(File.join(@roles_dir, 'fallback.md'), '# Fallback')

    mock_parsed = mock('parsed')
    mock_parsed.stubs(:metadata).returns(nil)
    mock_parsed.stubs(:to_s).returns('Fallback Role')
    PM.stubs(:parse).with('roles/fallback').returns(mock_parsed)

    result = @handler.load_role_for_model('not_a_hash', 'fallback')
    assert_equal 'Fallback Role', result
  end

  def test_load_role_handles_error_gracefully
    @handler.stubs(:fetch_role).raises(StandardError, 'role error')

    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    result = @handler.load_role_for_model({ role: 'broken' })
    assert_nil result
    assert stderr_messages.any? { |m| m.include?('Could not load role') }
  end
end


class PromptHandlerApplyMetadataTest < Minitest::Test
  def setup
    @prompts_dir = Dir.mktmpdir
    @roles_dir = File.join(@prompts_dir, 'roles')
    Dir.mkdir(@roles_dir)

    @config = OpenStruct.new(
      models: ['test-model'],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048, top_p: nil),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      pipeline: [],
      prompts: OpenStruct.new(
        dir: @prompts_dir,
        extname: '.md',
        roles_dir: @roles_dir,
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: nil
      ),
      prompt_id: 'test_prompt'
    )
    AIA.stubs(:config).returns(@config)

    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.rm_rf(@prompts_dir)
    super
  end

  def test_apply_metadata_nil_parsed
    # Should not raise
    @handler.apply_metadata_config(nil)
  end

  def test_apply_metadata_nil_metadata
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(nil)

    # Should not raise
    @handler.apply_metadata_config(parsed)
  end

  def test_apply_model_shorthand
    metadata = OpenStruct.new(to_h: { 'model' => 'gpt-4o' })
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(metadata)

    @handler.apply_metadata_config(parsed)
    assert_equal ['gpt-4o'], @config.models
  end

  def test_apply_temperature_shorthand
    metadata = OpenStruct.new(to_h: { 'temperature' => 0.9 })
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(metadata)

    @handler.apply_metadata_config(parsed)
    assert_equal 0.9, @config.llm.temperature
  end

  def test_apply_top_p_shorthand
    metadata = OpenStruct.new(to_h: { 'top_p' => 0.95 })
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(metadata)

    @handler.apply_metadata_config(parsed)
    assert_equal 0.95, @config.llm.top_p
  end

  def test_apply_next_shorthand
    metadata = OpenStruct.new(to_h: { 'next' => 'follow_up' })
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(metadata)

    @handler.apply_metadata_config(parsed)
    assert_equal ['follow_up'], @config.pipeline
  end

  def test_apply_pipeline_shorthand
    metadata = OpenStruct.new(to_h: { 'pipeline' => ['a', 'b', 'c'] })
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(metadata)

    @handler.apply_metadata_config(parsed)
    assert_equal ['a', 'b', 'c'], @config.pipeline
  end

  def test_apply_shell_shorthand
    metadata = OpenStruct.new(to_h: { 'shell' => true })
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(metadata)

    @handler.apply_metadata_config(parsed)
    assert_equal true, @config.flags.shell
  end

  def test_apply_erb_shorthand
    metadata = OpenStruct.new(to_h: { 'erb' => true })
    parsed = mock('parsed')
    parsed.stubs(:metadata).returns(metadata)

    @handler.apply_metadata_config(parsed)
    assert_equal true, @config.flags.erb
  end
end


class PromptHandlerShorthandConflictsTest < Minitest::Test
  def setup
    @prompts_dir = Dir.mktmpdir
    @roles_dir = File.join(@prompts_dir, 'roles')
    Dir.mkdir(@roles_dir)

    AIA.stubs(:config).returns(OpenStruct.new(
      models: ['test-model'],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      pipeline: [],
      prompts: OpenStruct.new(
        dir: @prompts_dir,
        extname: '.md',
        roles_dir: @roles_dir,
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: nil
      ),
      prompt_id: 'test_prompt'
    ))

    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.rm_rf(@prompts_dir)
    super
  end

  def test_next_and_pipeline_conflict
    meta_hash = { 'next' => 'prompt_b', 'pipeline' => ['prompt_c'] }

    assert_raises(AIA::ConfigurationError) do
      @handler.send(:detect_shorthand_conflicts, meta_hash, nil)
    end
  end

  def test_temperature_root_and_config_conflict
    meta_hash = { 'temperature' => 0.5 }
    config_section = { temperature: 0.9 }

    assert_raises(AIA::ConfigurationError) do
      @handler.send(:detect_shorthand_conflicts, meta_hash, config_section)
    end
  end

  def test_no_conflict_when_only_root_key
    meta_hash = { 'temperature' => 0.5 }
    config_section = { llm: { max_tokens: 4096 } }

    # Should not raise
    @handler.send(:detect_shorthand_conflicts, meta_hash, config_section)
  end

  def test_no_conflict_when_no_config_section
    meta_hash = { 'model' => 'gpt-4o' }

    # Should not raise
    @handler.send(:detect_shorthand_conflicts, meta_hash, nil)
  end
end


class PromptHandlerHelperMethodsTest < Minitest::Test
  def setup
    @prompts_dir = Dir.mktmpdir
    @roles_dir = File.join(@prompts_dir, 'roles')
    Dir.mkdir(@roles_dir)

    AIA.stubs(:config).returns(OpenStruct.new(
      models: ['test-model'],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      pipeline: [],
      prompts: OpenStruct.new(
        dir: @prompts_dir,
        extname: '.md',
        roles_dir: @roles_dir,
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: nil
      ),
      prompt_id: 'test_prompt'
    ))

    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.rm_rf(@prompts_dir)
    super
  end

  # --- symbolize_keys_deep ---

  def test_symbolize_keys_deep_hash
    input = { 'a' => 1, 'b' => { 'c' => 2 } }
    result = @handler.send(:symbolize_keys_deep, input)
    assert_equal({ a: 1, b: { c: 2 } }, result)
  end

  def test_symbolize_keys_deep_array
    input = [{ 'a' => 1 }, { 'b' => 2 }]
    result = @handler.send(:symbolize_keys_deep, input)
    assert_equal([{ a: 1 }, { b: 2 }], result)
  end

  def test_symbolize_keys_deep_scalar
    assert_equal 42, @handler.send(:symbolize_keys_deep, 42)
    assert_equal 'hello', @handler.send(:symbolize_keys_deep, 'hello')
    assert_nil @handler.send(:symbolize_keys_deep, nil)
  end

  def test_symbolize_keys_deep_nested
    input = { 'llm' => { 'temperature' => 0.7, 'nested' => { 'key' => 'value' } } }
    result = @handler.send(:symbolize_keys_deep, input)
    assert_equal({ llm: { temperature: 0.7, nested: { key: 'value' } } }, result)
  end

  # --- dig_hash ---

  def test_dig_hash_single_key
    hash = { a: 1 }
    assert_equal 1, @handler.send(:dig_hash, hash, [:a])
  end

  def test_dig_hash_nested_keys
    hash = { a: { b: { c: 42 } } }
    assert_equal 42, @handler.send(:dig_hash, hash, [:a, :b, :c])
  end

  def test_dig_hash_missing_key_returns_nil
    hash = { a: 1 }
    assert_nil @handler.send(:dig_hash, hash, [:b])
  end

  def test_dig_hash_nil_intermediate_returns_nil
    hash = { a: nil }
    assert_nil @handler.send(:dig_hash, hash, [:a, :b])
  end

  def test_dig_hash_with_string_fallback
    hash = { 'a' => { 'b' => 99 } }
    assert_equal 99, @handler.send(:dig_hash, hash, [:a, :b])
  end

  # --- deep_merge_config ---

  def test_deep_merge_config_sets_simple_value
    config = OpenStruct.new(
      models: ['test-model'],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false),
      pipeline: [],
      prompts: OpenStruct.new(dir: @prompts_dir, extname: '.md', roles_dir: @roles_dir, roles_prefix: 'roles', role: nil, parameter_regex: nil)
    )
    AIA.stubs(:config).returns(config)

    handler = AIA::PromptHandler.new
    handler.send(:deep_merge_config, { llm: { temperature: 0.9 } })
    assert_equal 0.9, config.llm.temperature
  end

  def test_deep_merge_config_nested_values
    config = OpenStruct.new(
      models: ['test-model'],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false),
      pipeline: [],
      prompts: OpenStruct.new(dir: @prompts_dir, extname: '.md', roles_dir: @roles_dir, roles_prefix: 'roles', role: nil, parameter_regex: nil)
    )
    AIA.stubs(:config).returns(config)

    handler = AIA::PromptHandler.new
    handler.send(:deep_merge_config, { flags: { chat: true } })
    assert_equal true, config.flags.chat
  end

  # --- handle_missing_prompt ---

  def test_handle_missing_prompt_empty_id
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.send(:handle_missing_prompt, '')
    assert stderr_messages.any? { |m| m.include?('cannot be empty') }
  end

  def test_handle_missing_prompt_non_fuzzy_exits
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.send(:handle_missing_prompt, 'no_such_prompt')
    assert stderr_messages.any? { |m| m.include?('Could not find prompt') }
  end

  # --- handle_missing_role ---

  def test_handle_missing_role_empty
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.send(:handle_missing_role, '')
    assert stderr_messages.any? { |m| m.include?('Role ID cannot be empty') }
  end

  def test_handle_missing_role_roles_slash
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.send(:handle_missing_role, 'roles/')
    assert stderr_messages.any? { |m| m.include?('Role ID cannot be empty') }
  end

  def test_handle_missing_role_non_fuzzy_exits
    stderr_messages = []
    @handler.stubs(:warn).with { |msg| stderr_messages << msg; true }

    @handler.send(:handle_missing_role, 'no_such_role')
    assert stderr_messages.any? { |m| m.include?('Could not find role') }
  end
end


class PromptHandlerShorthandKeysTest < Minitest::Test
  def test_shorthand_keys_constant
    expected = %w[model temperature top_p next pipeline shell erb]
    assert_equal expected, AIA::PromptHandler::SHORTHAND_KEYS
  end

  def test_shorthand_conflicts_constant
    assert_kind_of Hash, AIA::PromptHandler::SHORTHAND_CONFLICTS
    assert_includes AIA::PromptHandler::SHORTHAND_CONFLICTS.keys, 'model'
    assert_includes AIA::PromptHandler::SHORTHAND_CONFLICTS.keys, 'temperature'
    assert_includes AIA::PromptHandler::SHORTHAND_CONFLICTS.keys, 'next'
    assert_includes AIA::PromptHandler::SHORTHAND_CONFLICTS.keys, 'pipeline'
  end
end
