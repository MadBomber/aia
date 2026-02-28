# frozen_string_literal: true
# test/aia/system_prompt_assembler_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class SystemPromptAssemblerTest < Minitest::Test
  def setup
    @config = create_test_config
  end

  def test_resolve_system_prompt_with_no_role
    @config.prompts.system_prompt = 'You are helpful'
    @config.prompts.role = nil

    model_spec = OpenStruct.new(name: 'gpt-4o', role: nil)
    result = AIA::SystemPromptAssembler.resolve_system_prompt(@config, model_spec)
    assert_equal 'You are helpful', result
  end

  def test_resolve_system_prompt_with_role
    @config.prompts.system_prompt = 'You are helpful'
    @config.prompts.role = 'expert'

    # Create a temp role file
    role_dir = File.join(@config.prompts.dir, 'roles')
    FileUtils.mkdir_p(role_dir)
    role_file = File.join(role_dir, 'expert.md')
    File.write(role_file, 'You are an expert.')

    model_spec = OpenStruct.new(name: 'gpt-4o', role: nil)
    result = AIA::SystemPromptAssembler.resolve_system_prompt(@config, model_spec)
    assert_equal "You are helpful\n\nYou are an expert.", result
  ensure
    FileUtils.rm_rf(@config.prompts.dir)
  end

  def test_resolve_system_prompt_with_model_spec_role_override
    @config.prompts.system_prompt = 'Base prompt'
    @config.prompts.role = nil

    role_dir = File.join(@config.prompts.dir, 'roles')
    FileUtils.mkdir_p(role_dir)
    File.write(File.join(role_dir, 'coder.md'), 'You are a coder.')

    model_spec = OpenStruct.new(name: 'gpt-4o', role: 'coder')
    result = AIA::SystemPromptAssembler.resolve_system_prompt(@config, model_spec)
    assert_equal "Base prompt\n\nYou are a coder.", result
  ensure
    FileUtils.rm_rf(@config.prompts.dir)
  end

  def test_build_identity_prompt_single_robot
    spec = OpenStruct.new(name: 'gpt-4o', provider: nil)
    roster = [{ name: 'Tobor', spec: spec }]

    prompt = AIA::SystemPromptAssembler.build_identity_prompt('Tobor', spec, roster)

    assert_match(/You are Tobor, powered by gpt-4o/, prompt)
    refute_match(/team/, prompt, "Single robot should not mention a team")
  end

  def test_build_identity_prompt_multi_robot
    spec1 = OpenStruct.new(name: 'gpt-4o', provider: nil)
    spec2 = OpenStruct.new(name: 'claude-sonnet-4-20250514', provider: nil)
    roster = [
      { name: 'Tobor', spec: spec1 },
      { name: 'Spark', spec: spec2 }
    ]

    prompt = AIA::SystemPromptAssembler.build_identity_prompt('Tobor', spec1, roster)

    assert_match(/You are part of a team/, prompt)
    assert_match(/Tobor.*← you/, prompt)
    assert_match(/Spark/, prompt)
    assert_match(/@name mentions/, prompt)
  end

  def test_build_identity_prompt_with_provider
    spec = OpenStruct.new(name: 'llama3', provider: 'ollama')
    roster = [{ name: 'Tobor', spec: spec }]

    prompt = AIA::SystemPromptAssembler.build_identity_prompt('Tobor', spec, roster)

    assert_match(/\(ollama\)/, prompt)
  end

  def test_load_role_content_missing_file
    result = AIA::SystemPromptAssembler.load_role_content(@config, 'nonexistent')
    assert_nil result
  end

  def test_load_role_content_with_existing_file
    role_dir = File.join(@config.prompts.dir, 'roles')
    FileUtils.mkdir_p(role_dir)
    File.write(File.join(role_dir, 'writer.md'), 'You write well.')

    result = AIA::SystemPromptAssembler.load_role_content(@config, 'writer')
    assert_equal 'You write well.', result
  ensure
    FileUtils.rm_rf(@config.prompts.dir)
  end

  def test_load_role_content_with_prefixed_path
    role_dir = File.join(@config.prompts.dir, 'roles')
    FileUtils.mkdir_p(role_dir)
    File.write(File.join(role_dir, 'writer.md'), 'You write well.')

    # Already has the roles prefix
    result = AIA::SystemPromptAssembler.load_role_content(@config, 'roles/writer')
    assert_equal 'You write well.', result
  ensure
    FileUtils.rm_rf(@config.prompts.dir)
  end

  private

  def create_test_config
    OpenStruct.new(
      prompts: OpenStruct.new(
        dir: Dir.mktmpdir('aia_test_prompts'),
        extname: '.md',
        roles_prefix: 'roles',
        role: nil,
        system_prompt: nil
      )
    )
  end
end
