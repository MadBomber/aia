# test/aia/directives/skill_directive_test.rb

require_relative '../../test_helper'
require 'ostruct'
require 'fileutils'
require 'stringio'
require_relative '../../../lib/aia'

class SkillDirectiveTest < Minitest::Test
  def setup
    @test_skills_dir = Dir.mktmpdir('aia_test_skills')
    @original_skills_dir = AIA::Directives::WebAndFile::SKILLS_DIR

    # Point SKILLS_DIR at the temp directory
    AIA::Directives::WebAndFile.send(:remove_const, :SKILLS_DIR)
    AIA::Directives::WebAndFile.const_set(:SKILLS_DIR, @test_skills_dir)

    # Create test skills
    create_skill('code-quality', "# Code Quality\nEnforce SOLID principles.")
    create_skill('code-assist', "# Code Assist\nHelp with coding tasks.")
    create_skill('frontend-design', "# Frontend Design\nBuild interfaces.")

    # Create a skill directory without SKILL.md
    FileUtils.mkdir_p(File.join(@test_skills_dir, 'empty-skill'))

    @original_stdout = $stdout
    @captured_stdout = StringIO.new
    $stdout = @captured_stdout

    @stderr_messages = []
    STDERR.stubs(:puts).with { |msg| @stderr_messages << msg; true }
  end

  def teardown
    $stdout = @original_stdout

    # Restore original SKILLS_DIR
    AIA::Directives::WebAndFile.send(:remove_const, :SKILLS_DIR)
    AIA::Directives::WebAndFile.const_set(:SKILLS_DIR, @original_skills_dir)

    FileUtils.rm_rf(@test_skills_dir)
    super
  end

  # --- /skill tests ---

  def test_skill_exact_match
    result = AIA::Directives::WebAndFile.skill(['code-quality'])
    assert_equal "# Code Quality\nEnforce SOLID principles.", result
  end

  def test_skill_prefix_match
    result = AIA::Directives::WebAndFile.skill(['front'])
    assert_equal "# Frontend Design\nBuild interfaces.", result
  end

  def test_skill_prefix_match_returns_first_alphabetically
    result = AIA::Directives::WebAndFile.skill(['code'])
    # code-assist comes before code-quality alphabetically
    assert_equal "# Code Assist\nHelp with coding tasks.", result
  end

  def test_skill_exact_match_takes_priority_over_prefix
    result = AIA::Directives::WebAndFile.skill(['code-quality'])
    assert_equal "# Code Quality\nEnforce SOLID principles.", result
  end

  def test_skill_no_argument_returns_nil
    result = AIA::Directives::WebAndFile.skill([])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: /skill requires a skill name") }
  end

  def test_skill_empty_argument_returns_nil
    result = AIA::Directives::WebAndFile.skill(['  '])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: /skill requires a skill name") }
  end

  def test_skill_no_matching_directory_returns_nil
    result = AIA::Directives::WebAndFile.skill(['nonexistent'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: No skill matching 'nonexistent'") }
  end

  def test_skill_directory_without_skill_md_returns_nil
    result = AIA::Directives::WebAndFile.skill(['empty-skill'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("has no SKILL.md") }
  end

  def test_skill_prefix_match_skips_dir_without_skill_md
    # 'empty' prefix matches 'empty-skill' which has no SKILL.md
    result = AIA::Directives::WebAndFile.skill(['empty'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("has no SKILL.md") }
  end

  # --- /skills tests ---

  def test_skills_lists_subdirectories
    AIA::Directives::WebAndFile.skills
    output = @captured_stdout.string

    assert_includes output, "Available Skills"
    assert_includes output, "code-assist"
    assert_includes output, "code-quality"
    assert_includes output, "empty-skill"
    assert_includes output, "frontend-design"
    assert_includes output, "Total: 4 skills"
  end

  def test_skills_returns_nil
    result = AIA::Directives::WebAndFile.skills
    assert_nil result
  end

  def test_skills_sorted_alphabetically
    AIA::Directives::WebAndFile.skills
    output = @captured_stdout.string
    lines = output.lines.map(&:strip).reject(&:empty?)

    skill_lines = lines.select { |l| l.start_with?('code-') || l.start_with?('empty') || l.start_with?('front') }
    assert_equal ['code-assist', 'code-quality', 'empty-skill', 'frontend-design'], skill_lines
  end

  def test_skills_empty_directory
    FileUtils.rm_rf(Dir.glob(File.join(@test_skills_dir, '*')))

    AIA::Directives::WebAndFile.skills
    output = @captured_stdout.string
    assert_includes output, "No skills found"
  end

  def test_skills_missing_directory
    AIA::Directives::WebAndFile.send(:remove_const, :SKILLS_DIR)
    AIA::Directives::WebAndFile.const_set(:SKILLS_DIR, '/nonexistent/path')

    AIA::Directives::WebAndFile.skills
    output = @captured_stdout.string
    assert_includes output, "No skills directory found"
  end

  def test_skills_excludes_files
    # Create a plain file (not a directory) in the skills dir
    File.write(File.join(@test_skills_dir, '_patterns.md'), 'not a skill')

    AIA::Directives::WebAndFile.skills
    output = @captured_stdout.string

    refute_includes output, "_patterns.md"
    assert_includes output, "Total: 4 skills"
  end

  private

  def create_skill(name, content)
    skill_dir = File.join(@test_skills_dir, name)
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), content)
  end
end
