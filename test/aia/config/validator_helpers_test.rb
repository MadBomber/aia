require_relative '../../test_helper'
require 'ostruct'
require 'tempfile'

class ValidatorHelpersTest < Minitest::Test
  # =========================================================================
  # first_sentences
  # =========================================================================

  def test_first_sentences_extracts_count
    text = "First sentence. Second sentence. Third sentence. Fourth sentence."
    result = AIA::ConfigValidator.send(:first_sentences, text, 2)
    assert_equal "First sentence. Second sentence.", result
  end

  def test_first_sentences_handles_fewer_than_count
    text = "Only one."
    result = AIA::ConfigValidator.send(:first_sentences, text, 3)
    assert_equal "Only one.", result
  end

  def test_first_sentences_handles_no_sentences
    text = "no punctuation here"
    result = AIA::ConfigValidator.send(:first_sentences, text, 3)
    assert_equal "no punctuation here", result
  end

  def test_first_sentences_normalizes_whitespace
    text = "First sentence.\n\nSecond sentence.   Third sentence."
    result = AIA::ConfigValidator.send(:first_sentences, text, 2)
    assert_equal "First sentence. Second sentence.", result
  end

  def test_first_sentences_handles_exclamation_and_question
    text = "Wow! Really? Yes."
    result = AIA::ConfigValidator.send(:first_sentences, text, 3)
    assert_equal "Wow! Really? Yes.", result
  end

  def test_first_sentences_empty_string
    result = AIA::ConfigValidator.send(:first_sentences, "", 3)
    assert_equal "", result
  end

  # =========================================================================
  # nest_markdown_headings
  # =========================================================================

  def test_nest_markdown_headings_level_3
    text = "# Top\n## Sub\nRegular text\n### Deep"
    result = AIA::ConfigValidator.send(:nest_markdown_headings, text, 3)
    assert_includes result, "#### Top"
    assert_includes result, "##### Sub"
    assert_includes result, "Regular text"
    assert_includes result, "###### Deep"
  end

  def test_nest_markdown_headings_level_2
    text = "# Heading"
    result = AIA::ConfigValidator.send(:nest_markdown_headings, text, 2)
    assert_equal "### Heading", result
  end

  def test_nest_markdown_headings_no_headings
    text = "Just plain text\nMore text"
    result = AIA::ConfigValidator.send(:nest_markdown_headings, text, 3)
    assert_equal text, result
  end

  # =========================================================================
  # normalize_boolean_flag
  # =========================================================================

  def test_normalize_boolean_flag_true_string
    flags = OpenStruct.new(chat: 'true')
    AIA::ConfigValidator.send(:normalize_boolean_flag, flags, :chat)
    assert_equal true, flags.chat
  end

  def test_normalize_boolean_flag_false_string
    flags = OpenStruct.new(chat: 'false')
    AIA::ConfigValidator.send(:normalize_boolean_flag, flags, :chat)
    assert_equal false, flags.chat
  end

  def test_normalize_boolean_flag_nil
    flags = OpenStruct.new(chat: nil)
    AIA::ConfigValidator.send(:normalize_boolean_flag, flags, :chat)
    assert_equal false, flags.chat
  end

  def test_normalize_boolean_flag_empty_string
    flags = OpenStruct.new(chat: '')
    AIA::ConfigValidator.send(:normalize_boolean_flag, flags, :chat)
    assert_equal false, flags.chat
  end

  def test_normalize_boolean_flag_already_true
    flags = OpenStruct.new(chat: true)
    AIA::ConfigValidator.send(:normalize_boolean_flag, flags, :chat)
    assert_equal true, flags.chat
  end

  def test_normalize_boolean_flag_already_false
    flags = OpenStruct.new(chat: false)
    AIA::ConfigValidator.send(:normalize_boolean_flag, flags, :chat)
    assert_equal false, flags.chat
  end

  def test_normalize_boolean_flag_other_truthy_value
    flags = OpenStruct.new(chat: 'yes')
    AIA::ConfigValidator.send(:normalize_boolean_flag, flags, :chat)
    assert_equal true, flags.chat
  end

  # =========================================================================
  # filter_mcp_servers
  # =========================================================================

  def test_filter_mcp_servers_no_filters
    config = OpenStruct.new(
      mcp_servers: [
        { name: 'server1' },
        { name: 'server2' }
      ],
      mcp_use: [],
      mcp_skip: []
    )
    result = AIA::ConfigValidator.send(:filter_mcp_servers, config)
    assert_equal 2, result.size
  end

  def test_filter_mcp_servers_with_use_list
    config = OpenStruct.new(
      mcp_servers: [
        { name: 'server1' },
        { name: 'server2' },
        { name: 'server3' }
      ],
      mcp_use: ['server1', 'server3'],
      mcp_skip: []
    )
    result = AIA::ConfigValidator.send(:filter_mcp_servers, config)
    assert_equal 2, result.size
    names = result.map { |s| s[:name] }
    assert_includes names, 'server1'
    assert_includes names, 'server3'
    refute_includes names, 'server2'
  end

  def test_filter_mcp_servers_with_skip_list
    config = OpenStruct.new(
      mcp_servers: [
        { name: 'server1' },
        { name: 'server2' },
        { name: 'server3' }
      ],
      mcp_use: [],
      mcp_skip: ['server2']
    )
    result = AIA::ConfigValidator.send(:filter_mcp_servers, config)
    assert_equal 2, result.size
    names = result.map { |s| s[:name] }
    refute_includes names, 'server2'
  end

  def test_filter_mcp_servers_nil_servers
    config = OpenStruct.new(mcp_servers: nil, mcp_use: [], mcp_skip: [])
    result = AIA::ConfigValidator.send(:filter_mcp_servers, config)
    assert_equal [], result
  end

  def test_filter_mcp_servers_with_string_keys
    config = OpenStruct.new(
      mcp_servers: [
        { 'name' => 'string_key_server' }
      ],
      mcp_use: ['string_key_server'],
      mcp_skip: []
    )
    result = AIA::ConfigValidator.send(:filter_mcp_servers, config)
    assert_equal 1, result.size
  end

  # =========================================================================
  # mcp_filter_active?
  # =========================================================================

  def test_mcp_filter_active_with_use_list
    config = OpenStruct.new(mcp_use: ['server1'], mcp_skip: [])
    assert AIA::ConfigValidator.send(:mcp_filter_active?, config)
  end

  def test_mcp_filter_active_with_skip_list
    config = OpenStruct.new(mcp_use: [], mcp_skip: ['server1'])
    assert AIA::ConfigValidator.send(:mcp_filter_active?, config)
  end

  def test_mcp_filter_not_active
    config = OpenStruct.new(mcp_use: [], mcp_skip: [])
    refute AIA::ConfigValidator.send(:mcp_filter_active?, config)
  end

  def test_mcp_filter_active_with_nil_lists
    config = OpenStruct.new(mcp_use: nil, mcp_skip: nil)
    refute AIA::ConfigValidator.send(:mcp_filter_active?, config)
  end

  # =========================================================================
  # dump_config
  # =========================================================================

  def test_dump_config_yaml
    Dir.mktmpdir do |dir|
      dump_path = File.join(dir, 'test_dump.yml')
      config = OpenStruct.new(
        prompt_id: 'test',
        dump_file: dump_path,
        setting1: 'value1',
        setting2: 42
      )

      # OpenStruct#to_h returns the hash
      AIA::ConfigValidator.send(:dump_config, config, dump_path)

      assert File.exist?(dump_path)
      content = File.read(dump_path)
      assert_includes content, 'setting1'
      assert_includes content, 'value1'
      # prompt_id and dump_file should be removed
      refute_includes content, 'prompt_id'
      refute_includes content, 'dump_file'
    end
  end

  def test_dump_config_unsupported_format
    config = OpenStruct.new(setting: 'value')
    assert_raises(RuntimeError) do
      AIA::ConfigValidator.send(:dump_config, config, '/tmp/config.txt')
    end
  end

  # =========================================================================
  # prepare_pipeline
  # =========================================================================

  def test_prepare_pipeline_prepends_prompt_id
    config = OpenStruct.new(prompt_id: 'test_prompt', pipeline: ['other'])
    AIA::ConfigValidator.send(:prepare_pipeline, config)
    assert_equal ['test_prompt', 'other'], config.pipeline
  end

  def test_prepare_pipeline_skips_nil_prompt_id
    config = OpenStruct.new(prompt_id: nil, pipeline: ['other'])
    AIA::ConfigValidator.send(:prepare_pipeline, config)
    assert_equal ['other'], config.pipeline
  end

  def test_prepare_pipeline_skips_empty_prompt_id
    config = OpenStruct.new(prompt_id: '', pipeline: ['other'])
    AIA::ConfigValidator.send(:prepare_pipeline, config)
    assert_equal ['other'], config.pipeline
  end

  def test_prepare_pipeline_skips_if_already_first
    config = OpenStruct.new(prompt_id: 'test', pipeline: ['test', 'other'])
    AIA::ConfigValidator.send(:prepare_pipeline, config)
    assert_equal ['test', 'other'], config.pipeline
  end

  # =========================================================================
  # configure_prompt_manager (deprecation warning)
  # =========================================================================

  def test_configure_prompt_manager_warns_on_parameter_regex
    config = OpenStruct.new(prompts: OpenStruct.new(parameter_regex: '\\[\\[.*?\\]\\]'))
    _output = capture_io do
      AIA::ConfigValidator.send(:configure_prompt_manager, config)
    end
    # Should warn about deprecation (captured in stderr)
  end

  def test_configure_prompt_manager_no_warn_without_regex
    config = OpenStruct.new(prompts: OpenStruct.new(parameter_regex: nil))
    _, err = capture_io do
      AIA::ConfigValidator.send(:configure_prompt_manager, config)
    end
    refute_includes err, "deprecated"
  end
end
