# frozen_string_literal: true

require_relative '../../test_helper'
require 'ostruct'
require 'tmpdir'

# Helper to capture stdout when the block raises an exception (e.g. ConfigurationError)
module ValidatorTestHelpers
  def capture_stdout_through_exception
    old_stdout = $stdout
    $stdout = StringIO.new
    begin
      yield
    rescue AIA::ConfigurationError
      # expected
    end
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  def capture_stderr_through_exception
    old_stderr = $stderr
    $stderr = StringIO.new
    begin
      yield
    rescue AIA::ConfigurationError
      # expected
    end
    $stderr.string
  ensure
    $stderr = old_stderr
  end
end

class ValidatorProcessPromptIdTest < Minitest::Test
  def test_extracts_prompt_id_when_prompt_file_exists
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'my_prompt.md'), '# test prompt')
      config = OpenStruct.new(
        prompts: OpenStruct.new(dir: dir, extname: '.md')
      )
      remaining = ['my_prompt']

      AIA.stubs(:bad_file?).with('my_prompt').returns(true)
      AIA.stubs(:good_file?).with(File.join(dir, 'my_prompt.md')).returns(true)

      AIA::ConfigValidator.send(:process_prompt_id_from_args, config, remaining)
      assert_equal 'my_prompt', config.prompt_id
      assert_empty remaining
    end
  end

  def test_does_not_extract_when_file_exists_as_path
    config = OpenStruct.new(
      prompts: OpenStruct.new(dir: '/tmp', extname: '.md')
    )
    remaining = ['existing_file.txt']

    AIA.stubs(:bad_file?).with('existing_file.txt').returns(false)
    AIA.stubs(:good_file?).returns(false)

    AIA::ConfigValidator.send(:process_prompt_id_from_args, config, remaining)
    assert_nil config.prompt_id
    assert_equal ['existing_file.txt'], remaining
  end

  def test_does_nothing_with_empty_args
    config = OpenStruct.new(prompts: OpenStruct.new(dir: '/tmp', extname: '.md'))
    remaining = []

    AIA::ConfigValidator.send(:process_prompt_id_from_args, config, remaining)
    assert_nil config.prompt_id
  end
end

class ValidatorContextFilesTest < Minitest::Test
  def test_sets_context_files_from_remaining_args
    Dir.mktmpdir do |dir|
      f1 = File.join(dir, 'file1.rb')
      f2 = File.join(dir, 'file2.rb')
      File.write(f1, '# f1')
      File.write(f2, '# f2')

      config = OpenStruct.new(context_files: [])

      AIA.stubs(:good_file?).with(f1).returns(true)
      AIA.stubs(:good_file?).with(f2).returns(true)

      AIA::ConfigValidator.send(:validate_and_set_context_files, config, [f1, f2])
      assert_equal [f1, f2], config.context_files
    end
  end

  def test_exits_on_bad_files
    config = OpenStruct.new(context_files: [])
    AIA.stubs(:good_file?).with('/nonexistent/file.rb').returns(false)

    error = assert_raises(AIA::ConfigurationError) do
      AIA::ConfigValidator.send(:validate_and_set_context_files, config, ['/nonexistent/file.rb'])
    end
    assert_includes error.message, 'do not exist'
  end

  def test_flag_typo_detection
    config = OpenStruct.new(context_files: [])
    AIA.stubs(:good_file?).with('_B').returns(false)

    error = assert_raises(AIA::ConfigurationError) do
      AIA::ConfigValidator.send(:validate_and_set_context_files, config, ['_B'])
    end
    assert_includes error.message, 'Did you mean'
    assert_includes error.message, '-B'
  end

  def test_does_nothing_with_empty_args
    config = OpenStruct.new(context_files: [])
    AIA::ConfigValidator.send(:validate_and_set_context_files, config, [])
    assert_empty config.context_files
  end

  def test_initializes_nil_context_files
    config = OpenStruct.new(context_files: nil)
    AIA.stubs(:good_file?).returns(true)

    AIA::ConfigValidator.send(:validate_and_set_context_files, config, ['file.rb'])
    assert_equal ['file.rb'], config.context_files
  end
end

class ValidatorExecutablePromptTest < Minitest::Test
  def test_detects_shebang_file_as_executable_prompt
    Dir.mktmpdir do |dir|
      exec_file = File.join(dir, 'script.rb')
      File.write(exec_file, "#!/usr/bin/env ruby\nputs 'hello'\nputs 'world'\n")

      config = OpenStruct.new(
        prompt_id: nil,
        context_files: [exec_file],
        executable_prompt_content: nil
      )

      AIA::ConfigValidator.send(:handle_executable_prompt, config)
      assert_equal '__EXECUTABLE_PROMPT__', config.prompt_id
      assert_equal "puts 'hello'\nputs 'world'\n", config.executable_prompt_content
      assert_empty config.context_files
    end
  end

  def test_skips_when_prompt_id_set
    config = OpenStruct.new(
      prompt_id: 'existing',
      context_files: ['file.rb']
    )

    AIA::ConfigValidator.send(:handle_executable_prompt, config)
    assert_equal 'existing', config.prompt_id
  end

  def test_skips_when_no_context_files
    config = OpenStruct.new(
      prompt_id: nil,
      context_files: nil
    )

    AIA::ConfigValidator.send(:handle_executable_prompt, config)
    assert_nil config.prompt_id
  end

  def test_skips_when_first_file_not_shebang
    Dir.mktmpdir do |dir|
      plain_file = File.join(dir, 'plain.txt')
      File.write(plain_file, "no shebang here\njust text\n")

      config = OpenStruct.new(
        prompt_id: nil,
        context_files: [plain_file]
      )

      AIA::ConfigValidator.send(:handle_executable_prompt, config)
      assert_nil config.prompt_id
    end
  end
end

class ValidatorStdinAsPromptTest < Minitest::Test
  def test_stdin_content_becomes_executable_prompt
    config = OpenStruct.new(
      prompt_id: nil,
      stdin_content: "some piped content\n",
      executable_prompt_content: nil
    )

    AIA::ConfigValidator.send(:handle_stdin_as_prompt, config)
    assert_equal '__EXECUTABLE_PROMPT__', config.prompt_id
    assert_equal "some piped content\n", config.executable_prompt_content
    assert_nil config.stdin_content
  end

  def test_strips_shebang_from_stdin
    config = OpenStruct.new(
      prompt_id: nil,
      stdin_content: "#!/usr/bin/env ruby\nputs 'hello'\n",
      executable_prompt_content: nil
    )

    AIA::ConfigValidator.send(:handle_stdin_as_prompt, config)
    assert_equal "puts 'hello'\n", config.executable_prompt_content
  end

  def test_skips_when_prompt_id_set
    config = OpenStruct.new(
      prompt_id: 'existing',
      stdin_content: "content"
    )

    AIA::ConfigValidator.send(:handle_stdin_as_prompt, config)
    assert_equal 'existing', config.prompt_id
  end

  def test_skips_when_stdin_empty
    config = OpenStruct.new(
      prompt_id: nil,
      stdin_content: "   \n  "
    )

    AIA::ConfigValidator.send(:handle_stdin_as_prompt, config)
    assert_nil config.prompt_id
  end

  def test_skips_when_stdin_nil
    config = OpenStruct.new(
      prompt_id: nil,
      stdin_content: nil
    )

    AIA::ConfigValidator.send(:handle_stdin_as_prompt, config)
    assert_nil config.prompt_id
  end
end

class ValidatorRequiredPromptIdTest < Minitest::Test
  def test_exits_when_no_prompt_id_and_not_chat_or_fuzzy
    config = OpenStruct.new(
      prompt_id: nil,
      flags: OpenStruct.new(chat: false, fuzzy: false)
    )

    error = assert_raises(AIA::ConfigurationError) do
      AIA::ConfigValidator.send(:validate_required_prompt_id, config)
    end
    assert_includes error.message, 'prompt ID is required'
  end

  def test_skips_when_prompt_id_present
    config = OpenStruct.new(
      prompt_id: 'my_prompt',
      flags: OpenStruct.new(chat: false, fuzzy: false)
    )

    AIA::ConfigValidator.expects(:warn).never
    AIA::ConfigValidator.send(:validate_required_prompt_id, config)
  end

  def test_skips_in_chat_mode
    config = OpenStruct.new(
      prompt_id: nil,
      flags: OpenStruct.new(chat: true, fuzzy: false)
    )

    AIA::ConfigValidator.expects(:warn).never
    AIA::ConfigValidator.send(:validate_required_prompt_id, config)
  end

  def test_skips_in_fuzzy_mode
    config = OpenStruct.new(
      prompt_id: nil,
      flags: OpenStruct.new(chat: false, fuzzy: true)
    )

    AIA::ConfigValidator.expects(:warn).never
    AIA::ConfigValidator.send(:validate_required_prompt_id, config)
  end
end

class ValidatorRoleConfigurationTest < Minitest::Test
  def test_prepends_roles_prefix
    config = OpenStruct.new(
      prompts: OpenStruct.new(
        role: 'architect',
        roles_prefix: 'roles',
        roles_dir: nil,
        dir: '/tmp/prompts'
      ),
      prompt_id: 'my_prompt',
      pipeline: []
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)
    assert_equal 'roles/architect', config.prompts.role
  end

  def test_does_not_double_prefix
    config = OpenStruct.new(
      prompts: OpenStruct.new(
        role: 'roles/architect',
        roles_prefix: 'roles',
        roles_dir: nil,
        dir: '/tmp/prompts'
      ),
      prompt_id: 'my_prompt',
      pipeline: []
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)
    assert_equal 'roles/architect', config.prompts.role
  end

  def test_skips_nil_role
    config = OpenStruct.new(
      prompts: OpenStruct.new(role: nil, roles_prefix: 'roles')
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)
    # Should not raise
  end

  def test_skips_empty_role
    config = OpenStruct.new(
      prompts: OpenStruct.new(role: '', roles_prefix: 'roles')
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)
    # Should not raise
  end

  def test_role_becomes_prompt_id_when_no_prompt_id
    config = OpenStruct.new(
      prompts: OpenStruct.new(
        role: 'architect',
        roles_prefix: 'roles',
        roles_dir: nil,
        dir: '/tmp/prompts'
      ),
      flags: OpenStruct.new(chat: false),
      prompt_id: nil,
      pipeline: []
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)
    assert_equal 'roles/architect', config.prompt_id
    assert_equal '', config.prompts.role
    assert_includes config.pipeline, 'roles/architect'
  end

  def test_role_not_promoted_to_prompt_id_in_chat_mode
    config = OpenStruct.new(
      prompts: OpenStruct.new(
        role: 'jersey_mike',
        roles_prefix: 'roles',
        roles_dir: nil,
        dir: '/tmp/prompts'
      ),
      flags: OpenStruct.new(chat: true),
      prompt_id: nil,
      pipeline: []
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)
    assert_nil config.prompt_id
    assert_equal 'roles/jersey_mike', config.prompts.role
    assert_empty config.pipeline
  end

  def test_process_role_configuration_does_not_mangle_absolute_path_role
    config = OpenStruct.new(
      prompts: OpenStruct.new(
        role: '/tmp/my-expert-role.md',
        roles_prefix: 'roles',
        dir: '/tmp/prompts',
        roles_dir: nil
      ),
      flags: OpenStruct.new(chat: false),
      prompt_id: 'some-prompt',
      pipeline: []
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)

    assert_equal '/tmp/my-expert-role.md', config.prompts.role
  end

  def test_process_role_configuration_does_not_mangle_tilde_path_role
    config = OpenStruct.new(
      prompts: OpenStruct.new(
        role: '~/prompts/my-role',
        roles_prefix: 'roles',
        dir: '/tmp/prompts',
        roles_dir: nil
      ),
      flags: OpenStruct.new(chat: false),
      prompt_id: 'some-prompt',
      pipeline: []
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)

    assert_equal '~/prompts/my-role', config.prompts.role
  end
end

class ValidatorPluginsDirTest < Minitest::Test
  def test_validate_plugins_dir_warns_when_missing
    config = OpenStruct.new(paths: OpenStruct.new(plugins_dir: '/definitely/missing/plugins'))

    _out, err = capture_io do
      AIA::ConfigValidator.send(:validate_plugins_dir, config)
    end

    assert_match(/configured plugins directory does not exist/, err)
  end

  def test_validate_plugins_dir_is_silent_when_directory_exists
    Dir.mktmpdir do |dir|
      config = OpenStruct.new(paths: OpenStruct.new(plugins_dir: dir))

      _out, err = capture_io do
        AIA::ConfigValidator.send(:validate_plugins_dir, config)
      end

      assert_equal '', err
    end
  end

  def test_validate_plugins_dir_is_silent_when_nil
    config = OpenStruct.new(paths: OpenStruct.new(plugins_dir: nil))

    _out, err = capture_io do
      AIA::ConfigValidator.send(:validate_plugins_dir, config)
    end

    assert_equal '', err
  end
end

class ValidatorFuzzySearchTest < Minitest::Test
  def test_sets_fuzzy_search_sentinel
    config = OpenStruct.new(
      flags: OpenStruct.new(fuzzy: true),
      prompt_id: nil
    )

    AIA::ConfigValidator.send(:handle_fuzzy_search_prompt_id, config)
    assert_equal '__FUZZY_SEARCH__', config.prompt_id
  end

  def test_skips_when_not_fuzzy
    config = OpenStruct.new(
      flags: OpenStruct.new(fuzzy: false),
      prompt_id: nil
    )

    AIA::ConfigValidator.send(:handle_fuzzy_search_prompt_id, config)
    assert_nil config.prompt_id
  end

  def test_skips_when_prompt_id_present
    config = OpenStruct.new(
      flags: OpenStruct.new(fuzzy: true),
      prompt_id: 'existing'
    )

    AIA::ConfigValidator.send(:handle_fuzzy_search_prompt_id, config)
    assert_equal 'existing', config.prompt_id
  end
end

class ValidatorDumpConfigTest < Minitest::Test
  def test_handle_dump_config_triggers_dump_and_exit
    Dir.mktmpdir do |dir|
      dump_path = File.join(dir, 'dump.yml')
      config = OpenStruct.new(
        dump_file: dump_path,
        setting: 'value'
      )

      result = nil
      capture_io { result = AIA::ConfigValidator.send(:handle_dump_config, config) }
      assert_equal :early_exit, result
      assert File.exist?(dump_path)
    end
  end

  def test_handle_dump_config_skips_when_no_dump_file
    config = OpenStruct.new(dump_file: nil)

    # Should not raise or write anything
    AIA::ConfigValidator.send(:handle_dump_config, config)
  end

  def test_dump_config_reports_unwritable_path_as_configuration_error
    Dir.mktmpdir do |dir|
      config = OpenStruct.new(setting: 'value')
      path   = File.join(dir, 'missing', 'dump.yml')

      error = assert_raises(AIA::ConfigurationError) do
        AIA::ConfigValidator.send(:dump_config, config, path)
      end
      assert_includes error.message, path
    end
  end
end

class ValidatorMcpListTest < Minitest::Test
  include ValidatorTestHelpers

  def test_lists_mcp_servers
    config = OpenStruct.new(
      mcp_list: true,
      list_tools: nil,
      mcp_servers: [
        { name: 'github', command: 'gh', args: ['mcp'] },
        { name: 'filesystem', command: 'fs', args: [] }
      ],
      mcp_use: [],
      mcp_skip: []
    )

    out = capture_stdout_through_exception do
      AIA::ConfigValidator.send(:handle_mcp_list, config)
    end
    assert_match(/github/, out)
    assert_match(/filesystem/, out)
    assert_match(/Configured MCP servers/, out)
  end

  def test_lists_filtered_mcp_servers
    config = OpenStruct.new(
      mcp_list: true,
      list_tools: nil,
      mcp_servers: [
        { name: 'github', command: 'gh', args: [] },
        { name: 'filesystem', command: 'fs', args: [] }
      ],
      mcp_use: ['github'],
      mcp_skip: []
    )

    out = capture_stdout_through_exception do
      AIA::ConfigValidator.send(:handle_mcp_list, config)
    end
    assert_match(/Active MCP servers/, out)
    assert_match(/github/, out)
  end

  def test_handles_no_servers
    config = OpenStruct.new(
      mcp_list: true,
      list_tools: nil,
      mcp_servers: [],
      mcp_use: [],
      mcp_skip: []
    )

    out = capture_stdout_through_exception do
      AIA::ConfigValidator.send(:handle_mcp_list, config)
    end
    assert_match(/No MCP servers configured/, out)
  end

  def test_skips_when_mcp_list_false
    config = OpenStruct.new(mcp_list: nil)

    # Should return without doing anything
    AIA::ConfigValidator.send(:handle_mcp_list, config)
  end

  def test_defers_to_list_tools_when_both_set
    config = OpenStruct.new(
      mcp_list: true,
      list_tools: true
    )

    # Should return without doing mcp_list output (defers to handle_list_tools)
    out, _err = capture_io do
      AIA::ConfigValidator.send(:handle_mcp_list, config)
    end
    refute_match(/MCP servers/, out)
  end

  def test_handles_string_keys
    config = OpenStruct.new(
      mcp_list: true,
      list_tools: nil,
      mcp_servers: [
        { 'name' => 'test-server', 'command' => 'test', 'args' => ['--flag'] }
      ],
      mcp_use: [],
      mcp_skip: []
    )

    out = capture_stdout_through_exception do
      AIA::ConfigValidator.send(:handle_mcp_list, config)
    end
    assert_match(/test-server/, out)
    assert_match(/--flag/, out)
  end
end

class ValidatorCompletionScriptTest < Minitest::Test
  def test_handle_completion_script_skips_when_nil
    config = OpenStruct.new(completion: nil)
    AIA::ConfigValidator.send(:handle_completion_script, config)
    # Should not raise
  end

  def test_generate_completion_script_missing_shell
    error = assert_raises(AIA::ConfigurationError) do
      AIA::ConfigValidator.send(:generate_completion_script, 'nonexistent_shell')
    end
    assert_includes error.message, 'not supported'
  end

  def test_generate_completion_script_existing_shell
    # Check if any completion script exists
    script_dir = File.join(File.dirname(__FILE__), '../../../lib/aia')
    bash_script = File.join(script_dir, 'aia_completion.bash')

    if File.exist?(bash_script)
      out, _err = capture_io do
        AIA::ConfigValidator.send(:generate_completion_script, 'bash')
      end
      refute_empty out
    else
      skip "No bash completion script found at #{bash_script}"
    end
  end
end

class ValidatorPromptSelectionTest < Minitest::Test
  def config_with(**overrides)
    OpenStruct.new(
      {
        flags: OpenStruct.new(chat: false, fuzzy: false),
        prompts: OpenStruct.new(role: nil, roles_prefix: 'roles', roles_dir: nil, dir: '/tmp/prompts', extname: '.md'),
        prompt_id: nil,
        pipeline: [],
        context_files: []
      }.merge(overrides)
    )
  end

  def test_pipeline_head_becomes_prompt_id
    config = config_with(pipeline: %w[first second])
    AIA::ConfigValidator.send(:adopt_pipeline_head, config)
    assert_equal 'first', config.prompt_id
  end

  def test_pipeline_head_does_not_replace_prompt_id
    config = config_with(prompt_id: 'given', pipeline: %w[first])
    AIA::ConfigValidator.send(:adopt_pipeline_head, config)
    assert_equal 'given', config.prompt_id
  end

  def test_pipeline_head_ignores_empty_pipeline
    config = config_with
    AIA::ConfigValidator.send(:adopt_pipeline_head, config)
    assert_nil config.prompt_id
  end

  def test_role_alone_passes_required_prompt_check
    config = config_with
    config.prompts.role = 'tutor'
    AIA::ConfigValidator.send(:process_role_configuration, config)
    AIA::ConfigValidator.send(:validate_required_prompt_id, config)
    assert_equal 'roles/tutor', config.prompt_id
  end

  def test_role_with_pipeline_stays_a_role
    config = config_with(pipeline: %w[first])
    config.prompts.role = 'tutor'
    AIA::ConfigValidator.send(:adopt_pipeline_head, config)
    AIA::ConfigValidator.send(:process_role_configuration, config)
    assert_equal 'first', config.prompt_id
    assert_equal 'roles/tutor', config.prompts.role
    assert_equal %w[first], config.pipeline
  end

  def test_context_files_alone_still_need_a_prompt
    config = config_with(context_files: ['file.rb'])
    error = assert_raises(AIA::ConfigurationError) do
      AIA::ConfigValidator.send(:validate_required_prompt_id, config)
    end
    assert_includes error.message, 'Context files alone are not a prompt'
    refute_includes error.message, 'or providing context files'
  end

  def test_mistyped_prompt_id_names_the_prompt
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'code_review.md'), 'Review this')
      config = config_with(prompts: OpenStruct.new(dir: dir, extname: '.md'))

      error = assert_raises(AIA::ConfigurationError) do
        AIA::ConfigValidator.send(:validate_and_set_context_files, config, ['code-review'])
      end
      assert_includes error.message, "No prompt named 'code-review'"
      assert_includes error.message, 'Did you mean: code_review?'
    end
  end

  def test_mistyped_prompt_id_also_lists_missing_files
    Dir.mktmpdir do |dir|
      config = config_with(prompts: OpenStruct.new(dir: dir, extname: '.md'))

      error = assert_raises(AIA::ConfigurationError) do
        AIA::ConfigValidator.send(:validate_and_set_context_files, config, %w[nothing gone.rb])
      end
      assert_includes error.message, "No prompt named 'nothing'"
      assert_includes error.message, 'The following files do not exist: gone.rb'
      refute_includes error.message, 'Did you mean'
    end
  end

  def test_missing_file_with_extension_is_still_a_missing_file
    config = config_with
    error = assert_raises(AIA::ConfigurationError) do
      AIA::ConfigValidator.send(:validate_and_set_context_files, config, ['gone.rb'])
    end
    assert_equal 'The following files do not exist: gone.rb', error.message
  end

  def test_strip_shebang_from_piped_text
    text = "\n#!/usr/bin/env aia\n---\nmodel: x\n---\nHello\n"
    assert_equal "---\nmodel: x\n---\nHello\n", AIA::ConfigValidator.send(:strip_shebang, text)
  end

  def test_strip_shebang_drops_leading_newline_only
    assert_equal "---\na: 1\n---\nHi", AIA::ConfigValidator.send(:strip_shebang, "\n---\na: 1\n---\nHi")
  end

  def test_piped_prompt_keeps_front_matter
    config = config_with(stdin_content: "\n#!/usr/bin/env aia\n---\ntemperature: 0.2\n---\nHello")
    AIA::ConfigValidator.send(:handle_stdin_as_prompt, config)
    assert_equal '__EXECUTABLE_PROMPT__', config.prompt_id
    assert_equal "---\ntemperature: 0.2\n---\nHello", config.executable_prompt_content
  end

  def test_pipeline_validation_accepts_path_based_ids
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'my-role.md')
      File.write(path, 'You are kind.')
      config = config_with(pipeline: [path.delete_suffix('.md')])
      AIA::ConfigValidator.send(:validate_pipeline_prompts, config)
    end
  end
end

class ValidatorPipelineTest < Minitest::Test
  def test_validate_pipeline_prompts_passes_for_existing_files
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'prompt1.md'), '# prompt 1')
      File.write(File.join(dir, 'prompt2.md'), '# prompt 2')

      config = OpenStruct.new(
        pipeline: %w[prompt1 prompt2],
        prompts: OpenStruct.new(dir: dir, extname: '.md')
      )

      _out, err = capture_io do
        AIA::ConfigValidator.send(:validate_pipeline_prompts, config)
      end
      refute_match(/does not exist/, err)
    end
  end

  def test_validate_pipeline_prompts_reports_missing_files
    Dir.mktmpdir do |dir|
      config = OpenStruct.new(
        pipeline: ['nonexistent_prompt'],
        prompts: OpenStruct.new(dir: dir, extname: '.md')
      )

      error = assert_raises(AIA::ConfigurationError) do
        capture_io do
          AIA::ConfigValidator.send(:validate_pipeline_prompts, config)
        end
      end
      assert_includes error.message, 'do not exist'
    end
  end

  def test_validate_pipeline_prompts_skips_sentinels
    config = OpenStruct.new(
      pipeline: %w[__FUZZY_SEARCH__ __EXECUTABLE_PROMPT__],
      prompts: OpenStruct.new(dir: '/tmp', extname: '.md')
    )

    _out, err = capture_io do
      AIA::ConfigValidator.send(:validate_pipeline_prompts, config)
    end
    refute_match(/does not exist/, err)
  end

  def test_validate_pipeline_prompts_skips_empty_pipeline
    config = OpenStruct.new(pipeline: [])

    # Should not raise
    AIA::ConfigValidator.send(:validate_pipeline_prompts, config)
  end

  def test_validate_pipeline_prompts_skips_nil_entries
    config = OpenStruct.new(
      pipeline: [nil, '', '__FUZZY_SEARCH__'],
      prompts: OpenStruct.new(dir: '/tmp', extname: '.md')
    )

    _out, err = capture_io do
      AIA::ConfigValidator.send(:validate_pipeline_prompts, config)
    end
    refute_match(/does not exist/, err)
  end
end

class ValidatorNormalizeBooleanFlagsTest < Minitest::Test
  def test_normalizes_all_flags
    config = OpenStruct.new(
      flags: OpenStruct.new(chat: 'true', fuzzy: 'false', consensus: nil)
    )

    AIA::ConfigValidator.send(:normalize_boolean_flags, config)
    assert_equal true, config.flags.chat
    assert_equal false, config.flags.fuzzy
    assert_equal false, config.flags.consensus
  end
end

class ValidatorListToolsTest < Minitest::Test
  include ValidatorTestHelpers

  def test_handle_list_tools_skips_when_not_set
    config = OpenStruct.new(list_tools: nil)

    # Should not raise
    AIA::ConfigValidator.send(:handle_list_tools, config)
  end

  def test_handle_list_tools_reports_no_tools
    config = OpenStruct.new(
      list_tools: true,
      mcp_list: nil,
      require_libs: nil,
      tools: OpenStruct.new(paths: nil)
    )

    # The session tool loader finds nothing
    AIA::ToolLoader.stubs(:load_tools)
    AIA::ToolLoader.stubs(:filtered_tools).returns([])

    err = capture_stderr_through_exception do
      AIA::ConfigValidator.send(:handle_list_tools, config)
    end
    assert_match(/No tools available/, err)
  end

  # --list-tools builds servers the way MCPConnectionManager does
  # (RobotLab::MCP.build), so it lists the RubyLLM::MCP::Tools a robot gets
  def test_load_mcp_tools_grouped_uses_robot_lab_mcp_build
    tool   = Struct.new(:name, :description).new('lookup', 'Find things')
    server = mock('mcp_server')
    server.stubs(:tools).returns([tool])
    server.expects(:close).once
    RobotLab::MCP.expects(:build).with(has_entry(name: 'svc')).returns(server)

    groups = nil
    _, err = capture_io { groups = AIA::ConfigValidator.send(:load_mcp_tools_grouped, list_tools_config) }

    assert_equal ['svc'], groups.keys
    assert_equal [tool], groups['svc']
    assert_match(/svc... 1 tools/, err)
  end

  def test_load_mcp_tools_grouped_reports_failed_server
    server = mock('mcp_server')
    server.stubs(:tools).raises(RubyLLM::Error.new('spawn failed'))
    server.expects(:close).once
    RobotLab::MCP.stubs(:build).returns(server)

    groups = nil
    _, err = capture_io { groups = AIA::ConfigValidator.send(:load_mcp_tools_grouped, list_tools_config) }

    assert_empty groups
    assert_match(/svc... error: spawn failed/, err)
  end

  def test_load_mcp_tools_grouped_reports_connection_error
    RobotLab::MCP.stubs(:build).raises(StandardError.new('boom'))

    groups = nil
    _, err = capture_io { groups = AIA::ConfigValidator.send(:load_mcp_tools_grouped, list_tools_config) }

    assert_empty groups
    assert_match(/svc... error: boom/, err)
  end

  private

  def list_tools_config
    OpenStruct.new(
      list_tools: true, mcp_list: true,
      mcp_servers: [{ name: 'svc', command: 'svc-bin', args: [] }],
      mcp_use: [], mcp_skip: []
    )
  end
end

class ValidatorListToolsFilterTest < Minitest::Test
  def test_list_tools_uses_the_session_loader_and_filters
    config = OpenStruct.new(tools: OpenStruct.new(allowed: ['date'], rejected: []))
    AIA::ToolLoader.expects(:load_tools).with(config)
    AIA::ToolLoader.expects(:filtered_tools).with(config).returns([:date_tool])
    assert_equal [:date_tool], AIA::ConfigValidator.send(:load_local_tools, config)
  end

  def test_mcp_list_applies_use_and_skip_together
    servers = [{ name: 'a' }, { name: 'b' }, { name: 'c' }]
    config = OpenStruct.new(mcp_servers: servers, mcp_use: %w[a b], mcp_skip: %w[b])
    assert_equal [{ name: 'a' }], AIA::ConfigValidator.send(:filter_mcp_servers, config)
  end
end
