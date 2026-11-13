# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'

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

  def test_parses_skill_single
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--skill', 'testing'])
    assert_equal ['testing'], options[:skills]
  end

  def test_parses_skill_short_flag
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['-s', 'testing'])
    assert_equal ['testing'], options[:skills]
  end

  def test_parses_skill_comma_separated
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--skill', 'testing,debugging'])
    assert_equal %w[testing debugging], options[:skills]
  end

  def test_parses_skill_repeatable
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--skill', 'testing', '--skill', 'debugging'])
    assert_equal %w[testing debugging], options[:skills]
  end

  def test_parses_skill_combined_comma_and_repeat
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--skill', 'testing,debugging', '--skill', 'refactoring'])
    assert_equal %w[testing debugging refactoring], options[:skills]
  end

  def test_parses_skill_strips_whitespace
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--skill', ' testing , debugging '])
    assert_equal %w[testing debugging], options[:skills]
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
    assert_equal %w[a b c], options[:pipeline]
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
    assert_equal %w[lib1 lib2], options[:require_libs]
  end

  def test_require_libs_strips_spaces_around_commas
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--require', 'json, yaml,'])
    assert_equal %w[json yaml], options[:require_libs]
  end

  def test_repeated_tools_flags_accumulate
    Dir.mktmpdir do |dir|
      a = File.join(dir, 'a.rb')
      b = File.join(dir, 'b.rb')
      File.write(a, '')
      File.write(b, '')
      options = {}
      parser = AIA::CLIParser.send(:create_option_parser, options)
      parser.parse!(['--tools', a, '--tools', b])
      assert_equal [a, b], options[:tool_paths]
    end
  end

  def test_parses_allowed_tools
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--at', 'tool1,tool2'])
    assert_equal %w[tool1 tool2], options[:allowed_tools]
  end

  def test_parses_rejected_tools
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse!(['--rt', 'tool1,tool2'])
    assert_equal %w[tool1 tool2], options[:rejected_tools]
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
    assert_equal %w[server1 server2], options[:mcp_use]
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

    _, err = capture_io { parser.parse!(['--log-level', 'invalid']) }
    assert_includes err, 'Invalid log level'
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

  def test_removed_options_are_invalid
    %w[--md --no-markdown --expert-routing --load --save].each do |flag|
      parser = AIA::CLIParser.send(:create_option_parser, {})
      assert_raises(OptionParser::InvalidOption, flag) { parser.parse!([flag]) }
    end
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

      _, err = capture_io { AIA::CLIParser.send(:process_tools_paths, txt_file) }
      assert_includes err, 'should have *.rb extension'
    end
  end

  def test_rejects_nonexistent_path
    _, err = capture_io do
      AIA::CLIParser.send(:process_tools_paths, '/nonexistent/path/tool.rb')
    end
    assert_includes err, 'not valid'
  end
end
