require_relative '../../test_helper'

class SkillsConfigTest < Minitest::Test
  def setup
    @config = AIA::Config.new
  end

  def test_skills_dir_defaults_to_prompts_slash_skills
    expected = File.expand_path('~/.prompts/skills')
    assert_equal expected, @config.skills.dir
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
end
