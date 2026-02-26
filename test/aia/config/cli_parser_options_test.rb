# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'

class CLIParserValidateRoleExistsTest < Minitest::Test
  def test_validate_role_exists_with_valid_role
    Dir.mktmpdir do |dir|
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)
      File.write(File.join(roles_dir, 'architect.md'), '# Architect')

      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      # Should not raise
      AIA::CLIParser.send(:validate_role_exists, 'architect')
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end

  def test_validate_role_exists_with_prefixed_role
    Dir.mktmpdir do |dir|
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)
      File.write(File.join(roles_dir, 'architect.md'), '# Architect')

      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      # Should not raise when role already has prefix
      AIA::CLIParser.send(:validate_role_exists, 'roles/architect')
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end

  def test_validate_role_exists_raises_with_missing_role
    Dir.mktmpdir do |dir|
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)
      File.write(File.join(roles_dir, 'architect.md'), '# Architect')

      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      error = assert_raises(ArgumentError) do
        AIA::CLIParser.send(:validate_role_exists, 'nonexistent')
      end
      assert_match(/Role file not found/, error.message)
      assert_match(/Available roles/, error.message)
      assert_match(/architect/, error.message)
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end

  def test_validate_role_exists_raises_with_no_roles_dir
    Dir.mktmpdir do |dir|
      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      error = assert_raises(ArgumentError) do
        AIA::CLIParser.send(:validate_role_exists, 'nonexistent')
      end
      assert_match(/Role file not found/, error.message)
      assert_match(/No roles directory/, error.message)
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end
end


class CLIParserListRolesTest < Minitest::Test
  def test_list_available_roles_with_roles
    Dir.mktmpdir do |dir|
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)
      File.write(File.join(roles_dir, 'architect.md'), '')
      File.write(File.join(roles_dir, 'reviewer.md'), '')

      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      out, _err = capture_io do
        AIA::CLIParser.send(:list_available_roles)
      end
      assert_match(/Available roles/, out)
      assert_match(/architect/, out)
      assert_match(/reviewer/, out)
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end

  def test_list_available_roles_with_empty_dir
    Dir.mktmpdir do |dir|
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)

      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      out, _err = capture_io do
        AIA::CLIParser.send(:list_available_roles)
      end
      assert_match(/No role files found/, out)
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end

  def test_list_available_roles_no_dir
    Dir.mktmpdir do |dir|
      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'nonexistent_roles'

      out, _err = capture_io do
        AIA::CLIParser.send(:list_available_roles)
      end
      assert_match(/No roles directory/, out)
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end
end


class CLIParserCreateOptionParserTest < Minitest::Test
  def test_create_option_parser_returns_parser
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    assert_kind_of OptionParser, parser
  end

  def test_banner_includes_usage
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    assert_match(/Usage:/, parser.banner)
  end

  def test_parses_chat_flag
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--chat'])
    assert_equal true, options[:chat]
  end

  def test_parses_temperature
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-t', '0.5'])
    assert_equal 0.5, options[:temperature]
  end

  def test_parses_max_tokens
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--max-tokens', '4096'])
    assert_equal 4096, options[:max_tokens]
  end

  def test_parses_top_p
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--top-p', '0.9'])
    assert_equal 0.9, options[:top_p]
  end

  def test_parses_frequency_penalty
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--frequency-penalty', '0.5'])
    assert_equal 0.5, options[:frequency_penalty]
  end

  def test_parses_presence_penalty
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--presence-penalty', '0.3'])
    assert_equal 0.3, options[:presence_penalty]
  end

  def test_parses_output_file
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-o', '/tmp/out.md'])
    assert_equal '/tmp/out.md', options[:output]
  end

  def test_parses_output_default
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-o'])
    assert_equal 'temp.md', options[:output]
  end

  def test_parses_no_output
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--no-output'])
    assert_nil options[:output]
  end

  def test_parses_append_flag
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-a'])
    assert_equal true, options[:append]
  end

  def test_parses_no_append
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--no-append'])
    assert_equal false, options[:append]
  end

  def test_parses_verbose
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-v'])
    assert_equal true, options[:verbose]
  end

  def test_parses_debug
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-d'])
    assert_equal true, options[:debug]
    assert_equal 'debug', options[:log_level_override]
  end

  def test_parses_no_debug
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--no-debug'])
    assert_equal false, options[:debug]
  end

  def test_parses_config_file
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-c', '/tmp/config.yml'])
    assert_equal '/tmp/config.yml', options[:extra_config_file]
  end

  def test_parses_prompts_dir
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--prompts-dir', '/tmp/my_prompts'])
    assert_equal '/tmp/my_prompts', options[:prompts_dir]
  end

  def test_parses_roles_prefix
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--roles-prefix', 'my_roles'])
    assert_equal 'my_roles', options[:roles_prefix]
  end

  def test_parses_role
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-r', 'architect'])
    assert_equal 'architect', options[:role]
  end

  def test_parses_next_prompt
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-n', 'next_prompt'])
    assert_equal ['next_prompt'], options[:pipeline]
  end

  def test_parses_pipeline
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-p', 'a,b,c'])
    assert_equal ['a', 'b', 'c'], options[:pipeline]
  end

  def test_parses_system_prompt
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--system-prompt', 'my_system'])
    assert_equal 'my_system', options[:system_prompt]
  end

  def test_parses_speak
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--speak'])
    assert_equal true, options[:speak]
  end

  def test_parses_voice
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--voice', 'nova'])
    assert_equal 'nova', options[:voice]
  end

  def test_parses_image_size
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--is', '512x512'])
    assert_equal '512x512', options[:image_size]
  end

  def test_parses_image_quality
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--iq', 'hd'])
    assert_equal 'hd', options[:image_quality]
  end

  def test_parses_require_libs
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--rq', 'lib1,lib2'])
    assert_equal ['lib1', 'lib2'], options[:require_libs]
  end

  def test_parses_allowed_tools
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--at', 'tool1,tool2'])
    assert_equal ['tool1', 'tool2'], options[:allowed_tools]
  end

  def test_parses_rejected_tools
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--rt', 'tool1,tool2'])
    assert_equal ['tool1', 'tool2'], options[:rejected_tools]
  end

  def test_parses_list_tools
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--list-tools'])
    assert_equal true, options[:list_tools]
  end

  def test_parses_tokens
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--tokens'])
    assert_equal true, options[:tokens]
  end

  def test_parses_cost_implies_tokens
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--cost'])
    assert_equal true, options[:cost]
    assert_equal true, options[:tokens]
  end

  def test_parses_mcp_file
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--mcp', '/tmp/mcp.json'])
    assert_equal ['/tmp/mcp.json'], options[:mcp_files]
  end

  def test_parses_multiple_mcp_files
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--mcp', '/tmp/a.json', '--mcp', '/tmp/b.json'])
    assert_equal ['/tmp/a.json', '/tmp/b.json'], options[:mcp_files]
  end

  def test_parses_no_mcp
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--no-mcp'])
    assert_equal true, options[:no_mcp]
  end

  def test_parses_mcp_list
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--mcp-list'])
    assert_equal true, options[:mcp_list]
  end

  def test_parses_mcp_use
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--mu', 'server1,server2'])
    assert_equal ['server1', 'server2'], options[:mcp_use]
  end

  def test_parses_mcp_skip
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--ms', 'server1'])
    assert_equal ['server1'], options[:mcp_skip]
  end

  def test_parses_dump_file
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--dump', '/tmp/config.yml'])
    assert_equal '/tmp/config.yml', options[:dump_file]
  end

  def test_parses_completion
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--completion', 'bash'])
    assert_equal 'bash', options[:completion]
  end

  def test_parses_refresh
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--refresh', '14'])
    assert_equal 14, options[:refresh]
  end

  def test_parses_log_level_valid
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--log-level', 'warn'])
    assert_equal 'warn', options[:log_level_override]
  end

  def test_parses_log_level_invalid_exits
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)

    stderr_messages = []
    AIA::CLIParser.stubs(:warn).with { |msg| stderr_messages << msg; true }

    parser.parse!(['--log-level', 'invalid'])
    assert stderr_messages.any? { |m| m.include?('Invalid log level') }
  end

  def test_parses_log_to
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--log-to', '/tmp/aia.log'])
    assert_equal '/tmp/aia.log', options[:log_file_override]
  end

  def test_parses_consensus
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--consensus'])
    assert_equal true, options[:consensus]
  end

  def test_parses_no_consensus
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--no-consensus'])
    assert_equal false, options[:consensus]
  end

  def test_parses_markdown
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--md'])
    assert_equal true, options[:markdown]
  end

  def test_parses_no_markdown
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--no-markdown'])
    assert_equal false, options[:markdown]
  end

  def test_parses_terse_no_error
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)

    # --terse is deprecated but should not raise
    parser.parse!(['--terse'])
    # No option is set since it's a no-op deprecated flag
  end

  def test_parses_regex_stores_value
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)

    # --regex is deprecated but should still store the value
    parser.parse!(['--regex', '\\w+'])
    assert_equal '\\w+', options[:parameter_regex]
  end

  def test_parses_speech_model
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--sm', 'tts-1'])
    assert_equal 'tts-1', options[:speech_model]
  end

  def test_parses_transcription_model
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--tm', 'whisper-1'])
    assert_equal 'whisper-1', options[:transcription_model]
  end

  def test_parses_history_file
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--history-file', '/tmp/history.yml'])
    assert_equal '/tmp/history.yml', options[:history_file]
  end

  def test_parses_expert_routing
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--expert-routing'])
    assert_equal true, options[:expert_routing]
  end

  def test_parses_track_pipeline
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--track-pipeline'])
    assert_equal true, options[:track_pipeline]
  end

  def test_parses_concurrent_auto
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--concurrent-auto'])
    assert_equal true, options[:concurrent_auto]
  end
end


class CLIParserToolsPathsExtendedTest < Minitest::Test
  def test_rejects_non_rb_file
    Dir.mktmpdir do |dir|
      txt_file = File.join(dir, 'tool.txt')
      File.write(txt_file, '# not ruby')

      stderr_messages = []
      AIA::CLIParser.stubs(:warn).with { |msg| stderr_messages << msg; true }

      AIA::CLIParser.send(:process_tools_paths, txt_file)
      assert stderr_messages.any? { |m| m.include?('should have *.rb extension') }
    end
  end

  def test_rejects_nonexistent_path
    stderr_messages = []
    AIA::CLIParser.stubs(:warn).with { |msg| stderr_messages << msg; true }

    AIA::CLIParser.send(:process_tools_paths, '/nonexistent/path/tool.rb')
    assert stderr_messages.any? { |m| m.include?('not valid') }
  end
end
