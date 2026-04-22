require_relative '../../test_helper'

class SkillsConfigTest < Minitest::Test
  def setup
    @config = AIA::Config.new
  end

  def test_skills_dir_defaults_to_prompts_slash_skills
    expected = File.expand_path('~/.prompts/skills')
    assert_equal expected, @config.skills.dir
  end

  def test_skills_prefix_defaults_to_skills
    assert_equal 'skills', @config.prompts.skills_prefix
  end

  def test_skills_array_defaults_to_empty
    assert_equal [], @config.prompts.skills
  end

  def test_list_skills_attr_accessor_exists
    assert_respond_to @config, :list_skills
    assert_respond_to @config, :list_skills=
  end

  def test_skills_dir_cli_override
    config = AIA::Config.new(overrides: { skills_dir: '/custom/skills' })
    assert_equal '/custom/skills', config.skills.dir
  end

  def test_skills_prefix_cli_override
    config = AIA::Config.new(overrides: { skills_prefix: 'my_skills' })
    assert_equal 'my_skills', config.prompts.skills_prefix
  end

  def test_roles_section_exists
    assert_respond_to @config, :roles
    expected = File.expand_path('~/.prompts/roles')
    assert_equal expected, @config.roles.dir
  end

  def test_tools_dir_expanded
    assert_respond_to @config.tools, :dir
    assert_equal File.expand_path('~/.prompts/tools'), @config.tools.dir
  end
end
