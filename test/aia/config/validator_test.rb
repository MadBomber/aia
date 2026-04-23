# frozen_string_literal: true

require_relative '../../test_helper'
require 'ostruct'
require 'tmpdir'

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

    stderr_messages = []
    AIA::ConfigValidator.stubs(:warn).with { |msg| stderr_messages << msg; true }

    AIA::ConfigValidator.send(:validate_and_set_context_files, config, ['/nonexistent/file.rb'])
    assert stderr_messages.any? { |m| m.include?('do not exist') }
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

    stderr_messages = []
    AIA::ConfigValidator.stubs(:warn).with { |msg| stderr_messages << msg; true }

    AIA::ConfigValidator.send(:validate_required_prompt_id, config)
    assert stderr_messages.any? { |m| m.include?('prompt ID is required') }
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

  def test_sets_roles_dir
    config = OpenStruct.new(
      prompts: OpenStruct.new(
        role: 'architect',
        roles_prefix: 'roles',
        roles_dir: nil,
        dir: '/tmp/prompts'
      ),
      flags: OpenStruct.new(chat: false),
      prompt_id: 'existing',
      pipeline: []
    )

    AIA::ConfigValidator.send(:process_role_configuration, config)
    assert_equal '/tmp/prompts/roles', config.prompts.roles_dir
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

      _out, _err = capture_io do
        AIA::ConfigValidator.send(:handle_dump_config, config)
      end
      assert File.exist?(dump_path)
    end
  end

  def test_handle_dump_config_skips_when_no_dump_file
    config = OpenStruct.new(dump_file: nil)

    # Should not raise or write anything
    AIA::ConfigValidator.send(:handle_dump_config, config)
  end
end


class ValidatorMcpListTest < Minitest::Test
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

    out, _err = capture_io do
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

    out, _err = capture_io do
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

    out, _err = capture_io do
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

    out, _err = capture_io do
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
    stderr_messages = []
    AIA::ConfigValidator.stubs(:warn).with { |msg| stderr_messages << msg; true }

    AIA::ConfigValidator.send(:generate_completion_script, 'nonexistent_shell')
    assert stderr_messages.any? { |m| m.include?('not supported') }
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


class ValidatorFinalPromptRequirementsTest < Minitest::Test
  def test_exits_when_no_prompt_no_context_no_chat_no_fuzzy
    config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, fuzzy: false),
      prompt_id: nil,
      context_files: nil
    )

    stderr_messages = []
    AIA::ConfigValidator.stubs(:warn).with { |msg| stderr_messages << msg; true }

    AIA::ConfigValidator.send(:validate_final_prompt_requirements, config)
    assert stderr_messages.any? { |m| m.include?('prompt ID is required') }
  end

  def test_passes_with_prompt_id
    config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, fuzzy: false),
      prompt_id: 'my_prompt',
      context_files: nil
    )

    AIA::ConfigValidator.expects(:warn).never
    AIA::ConfigValidator.send(:validate_final_prompt_requirements, config)
  end

  def test_passes_in_chat_mode
    config = OpenStruct.new(
      flags: OpenStruct.new(chat: true, fuzzy: false),
      prompt_id: nil,
      context_files: nil
    )

    AIA::ConfigValidator.expects(:warn).never
    AIA::ConfigValidator.send(:validate_final_prompt_requirements, config)
  end

  def test_passes_in_fuzzy_mode
    config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, fuzzy: true),
      prompt_id: nil,
      context_files: nil
    )

    AIA::ConfigValidator.expects(:warn).never
    AIA::ConfigValidator.send(:validate_final_prompt_requirements, config)
  end

  def test_passes_with_context_files
    config = OpenStruct.new(
      flags: OpenStruct.new(chat: false, fuzzy: false),
      prompt_id: nil,
      context_files: ['file.rb']
    )

    AIA::ConfigValidator.expects(:warn).never
    AIA::ConfigValidator.send(:validate_final_prompt_requirements, config)
  end
end


class ValidatorPipelineTest < Minitest::Test
  def test_validate_pipeline_prompts_passes_for_existing_files
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'prompt1.md'), '# prompt 1')
      File.write(File.join(dir, 'prompt2.md'), '# prompt 2')

      config = OpenStruct.new(
        pipeline: ['prompt1', 'prompt2'],
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

      stderr_messages = []
      AIA::ConfigValidator.stubs(:warn).with { |msg| stderr_messages << msg; true }

      AIA::ConfigValidator.send(:validate_pipeline_prompts, config)
      assert stderr_messages.any? { |m| m.include?('does not exist') }
    end
  end

  def test_validate_pipeline_prompts_skips_sentinels
    config = OpenStruct.new(
      pipeline: ['__FUZZY_SEARCH__', '__EXECUTABLE_PROMPT__'],
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

    # Stub ObjectSpace to return no tool subclasses
    ObjectSpace.stubs(:each_object).with(Class).returns([].each)

    _out, err = capture_io do
      AIA::ConfigValidator.send(:handle_list_tools, config)
    end
    assert_match(/No tools available/, err)
  end
end
