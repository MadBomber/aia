# frozen_string_literal: true
# test/aia/multi_model_isolation_test.rb
# Tests for v2 multi-model support via RobotFactory

require_relative '../test_helper'
require_relative '../../lib/aia'
require 'tmpdir'
require 'fileutils'

class MultiModelTest < Minitest::Test
  def setup
    @temp_prompts_dir = Dir.mktmpdir('aia_test_prompts')

    config = create_test_config
    AIA.stubs(:config).returns(config)
  end

  def teardown
    FileUtils.rm_rf(@temp_prompts_dir) if @temp_prompts_dir && Dir.exist?(@temp_prompts_dir)
    super
  end

  private

  def create_test_config
    prompts_section = OpenStruct.new(
      dir: @temp_prompts_dir,
      roles_dir: File.join(@temp_prompts_dir, 'roles'),
      roles_prefix: 'roles',
      role: '',
      system_prompt: 'test system prompt',
      extname: '.md'
    )

    flags_section = OpenStruct.new(
      erb: true,
      shell: true,
      chat: false,
      fuzzy: false,
      verbose: false,
      debug: false,
      consensus: false,
      no_mcp: true,
      tokens: false
    )

    output_section = OpenStruct.new(
      file: nil,
      history_file: File.join(@temp_prompts_dir, '_prompts.log'),
      append: false,
      markdown: true
    )

    llm_section = OpenStruct.new(
      temperature: 0.7,
      max_tokens: 2048,
      top_p: 1.0,
      frequency_penalty: 0.0,
      presence_penalty: 0.0
    )

    tools_section = OpenStruct.new(
      paths: [],
      allowed: nil,
      rejected: nil
    )

    OpenStruct.new(
      prompts: prompts_section,
      flags: flags_section,
      output: output_section,
      llm: llm_section,
      tools: tools_section,
      models: [OpenStruct.new(name: 'gpt-4o', role: nil, instance: 1, internal_id: 'gpt-4o')],
      pipeline: [],
      context_files: [],
      mcp_servers: [],
      mcp_use: [],
      mcp_skip: [],
      require_libs: [],
      loaded_tools: [],
      tool_names: '',
      prompt_id: nil,
      rules: OpenStruct.new(dir: nil, enabled: false)
    )
  end

  public

  def test_single_model_config
    # Given: A single model config
    config = AIA.config
    assert_equal 1, config.models.length
    assert_equal 'gpt-4o', config.models.first.name
  end

  def test_multi_model_config
    # Given: Multiple models
    AIA.config.models = [
      OpenStruct.new(name: 'gpt-4o', role: nil, instance: 1, internal_id: 'gpt-4o'),
      OpenStruct.new(name: 'claude-3', role: 'reviewer', instance: 1, internal_id: 'claude-3')
    ]

    assert_equal 2, AIA.config.models.length
    assert_equal 'gpt-4o', AIA.config.models.first.name
    assert_equal 'claude-3', AIA.config.models.last.name
    assert_equal 'reviewer', AIA.config.models.last.role
  end

  def test_consensus_mode_flag
    AIA.config.flags.consensus = true
    assert AIA.config.flags.consensus
  end
end
