require_relative '../test_helper'
require 'fileutils'
require 'tmpdir'
require 'ostruct'
require_relative '../../lib/aia'

class PromptPipelineSkillsTest < Minitest::Test
  def setup
    @pipeline = AIA::PromptPipeline.allocate

    @skills_dir = Dir.mktmpdir('aia_pipeline_skills_dir')
    skills_config = OpenStruct.new(dir: @skills_dir)
    AIA.stubs(:config).returns(OpenStruct.new(skills: skills_config))
  end

  def teardown
    FileUtils.rm_rf(@skills_dir) if @skills_dir
    super
  end

  def test_load_skills_with_absolute_path
    skill_dir = Dir.mktmpdir('aia_pipeline_skill')
    File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: Pipeline Skill\n---\n# Pipeline Body")

    result = @pipeline.send(:load_skills, [skill_dir])
    assert_equal 1, result.length
    assert_equal '# Pipeline Body', result.first
  ensure
    FileUtils.rm_rf(skill_dir) if skill_dir
  end

  def test_load_skills_with_relative_path
    Dir.mktmpdir('aia_rel_pipeline') do |base|
      skill_dir = File.join(base, 'my-pipeline-skill')
      FileUtils.mkdir_p(skill_dir)
      File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: Relative\n---\n# Relative Body")

      Dir.chdir(base) do
        result = @pipeline.send(:load_skills, ['./my-pipeline-skill'])
        assert_equal 1, result.length
        assert_equal '# Relative Body', result.first
      end
    end
  end

  def test_load_skills_path_not_found_warns_and_skips
    _, err = capture_io do
      result = @pipeline.send(:load_skills, ['/nonexistent/absolute/my-skill'])
      assert_empty result
    end
    assert_match(/No skill directory found at/, err)
  end

  def test_load_skills_path_without_skill_md_warns_and_skips
    dir = Dir.mktmpdir('aia_no_md')
    _, err = capture_io do
      result = @pipeline.send(:load_skills, [dir])
      assert_empty result
    end
    assert_match(/has no SKILL\.md/, err)
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_load_skills_with_direct_md_file_path
    Dir.mktmpdir('aia_direct_md') do |dir|
      file = File.join(dir, 'my-skill.md')
      File.write(file, "---\nname: Direct MD Skill\n---\n# Direct MD Body")
      result = @pipeline.send(:load_skills, [file])
      assert_equal 1, result.length
      assert_equal '# Direct MD Body', result.first
    end
  end

  def test_load_skills_mixed_path_and_id
    # ID-based skill in configured dir
    id_skill_dir = File.join(@skills_dir, 'id-based-skill')
    FileUtils.mkdir_p(id_skill_dir)
    File.write(File.join(id_skill_dir, 'SKILL.md'), "---\nname: ID Skill\n---\n# ID Body")

    # Path-based skill in a separate tmpdir
    path_skill_dir = Dir.mktmpdir('aia_mixed_path_skill')
    File.write(File.join(path_skill_dir, 'SKILL.md'), "---\nname: Path Skill\n---\n# Path Body")

    result = @pipeline.send(:load_skills, ['id-based-skill', path_skill_dir])
    assert_equal 2, result.length
    assert_includes result, '# ID Body'
    assert_includes result, '# Path Body'
  ensure
    FileUtils.rm_rf(path_skill_dir) if path_skill_dir
  end
end
