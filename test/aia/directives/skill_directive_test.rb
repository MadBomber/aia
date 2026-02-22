require_relative '../../test_helper'
require 'ostruct'
require 'fileutils'
require 'stringio'
require_relative '../../../lib/aia'

class SkillDirectiveTest < Minitest::Test
  def setup
    @test_skills_dir = Dir.mktmpdir('aia_test_skills')
    @original_skills_dir = AIA::WebAndFileDirectives::SKILLS_DIR

    # Point SKILLS_DIR at the temp directory
    AIA::WebAndFileDirectives.send(:remove_const, :SKILLS_DIR)
    AIA::WebAndFileDirectives.const_set(:SKILLS_DIR, @test_skills_dir)

    # Create test skills
    create_skill('code-quality', "# Code Quality\nEnforce SOLID principles.")
    create_skill('code-assist', "# Code Assist\nHelp with coding tasks.")
    create_skill('frontend-design', "# Frontend Design\nBuild interfaces.")

    # Create a skill directory without SKILL.md
    FileUtils.mkdir_p(File.join(@test_skills_dir, 'empty-skill'))

    @instance = AIA::WebAndFileDirectives.new

    @original_stdout = $stdout
    @captured_stdout = StringIO.new
    $stdout = @captured_stdout

    @stderr_messages = []
    @instance.stubs(:warn).with { |msg| @stderr_messages << msg; true }
  end

  def teardown
    $stdout = @original_stdout

    # Restore original SKILLS_DIR
    AIA::WebAndFileDirectives.send(:remove_const, :SKILLS_DIR)
    AIA::WebAndFileDirectives.const_set(:SKILLS_DIR, @original_skills_dir)

    FileUtils.rm_rf(@test_skills_dir)
    super
  end

  # --- /skill tests ---

  def test_skill_exact_match
    result = @instance.skill(['code-quality'])
    assert_equal "# Code Quality\nEnforce SOLID principles.", result
  end

  def test_skill_prefix_match
    result = @instance.skill(['front'])
    assert_equal "# Frontend Design\nBuild interfaces.", result
  end

  def test_skill_prefix_match_returns_first_alphabetically
    result = @instance.skill(['code'])
    # code-assist comes before code-quality alphabetically
    assert_equal "# Code Assist\nHelp with coding tasks.", result
  end

  def test_skill_exact_match_takes_priority_over_prefix
    result = @instance.skill(['code-quality'])
    assert_equal "# Code Quality\nEnforce SOLID principles.", result
  end

  def test_skill_no_argument_returns_nil
    result = @instance.skill([])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: /skill requires a skill name") }
  end

  def test_skill_empty_argument_returns_nil
    result = @instance.skill(['  '])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: /skill requires a skill name") }
  end

  def test_skill_no_matching_directory_returns_nil
    result = @instance.skill(['nonexistent'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: No skill matching 'nonexistent'") }
  end

  def test_skill_directory_without_skill_md_returns_nil
    result = @instance.skill(['empty-skill'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("has no SKILL.md") }
  end

  def test_skill_prefix_match_skips_dir_without_skill_md
    # 'empty' prefix matches 'empty-skill' which has no SKILL.md
    result = @instance.skill(['empty'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("has no SKILL.md") }
  end

  # --- /skills tests ---

  def test_skills_lists_subdirectories
    @instance.skills
    output = @captured_stdout.string

    assert_includes output, "Available Skills"
    assert_includes output, "code-assist"
    assert_includes output, "code-quality"
    assert_includes output, "empty-skill"
    assert_includes output, "frontend-design"
    assert_includes output, "Total: 4 skills"
  end

  def test_skills_returns_nil
    result = @instance.skills
    assert_nil result
  end

  def test_skills_sorted_alphabetically
    @instance.skills
    output = @captured_stdout.string
    lines = output.lines.map(&:strip).reject(&:empty?)

    skill_lines = lines.select { |l| l.start_with?('code-') || l.start_with?('empty') || l.start_with?('front') }
    assert_equal ['code-assist', 'code-quality', 'empty-skill', 'frontend-design'], skill_lines
  end

  def test_skills_empty_directory
    FileUtils.rm_rf(Dir.glob(File.join(@test_skills_dir, '*')))

    @instance.skills
    output = @captured_stdout.string
    assert_includes output, "No skills found"
  end

  def test_skills_missing_directory
    AIA::WebAndFileDirectives.send(:remove_const, :SKILLS_DIR)
    AIA::WebAndFileDirectives.const_set(:SKILLS_DIR, '/nonexistent/path')

    @instance.skills
    output = @captured_stdout.string
    assert_includes output, "No skills directory found"
  end

  def test_skills_excludes_files
    # Create a plain file (not a directory) in the skills dir
    File.write(File.join(@test_skills_dir, '_patterns.md'), 'not a skill')

    @instance.skills
    output = @captured_stdout.string

    refute_includes output, "_patterns.md"
    assert_includes output, "Total: 4 skills"
  end

  # --- Security tests for safe_skill_path / path traversal ---

  def test_skill_path_traversal_blocked
    result = @instance.skill(['../../etc'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("No skill matching") }
  end

  def test_skill_symlink_outside_skills_dir_blocked
    # Create an external skill directory with a SKILL.md
    external_dir = Dir.mktmpdir('evil_skill')
    File.write(File.join(external_dir, 'SKILL.md'), '# Evil Skill')

    # Create a symlink inside SKILLS_DIR pointing outside
    symlink_path = File.join(@test_skills_dir, 'evil-link')
    File.symlink(external_dir, symlink_path)

    result = @instance.skill(['evil-link'])
    assert_nil result
  ensure
    FileUtils.rm_rf(external_dir)
  end

  def test_skill_broken_symlink_returns_nil
    # Create a symlink pointing to a nonexistent target
    symlink_path = File.join(@test_skills_dir, 'broken-link')
    File.symlink('/nonexistent/target/dir', symlink_path)

    result = @instance.skill(['broken-link'])
    assert_nil result
  end

  # --- Edge cases for resolve_skill_dir ---

  def test_skill_nil_argument_returns_nil
    result = @instance.skill(nil)
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: /skill requires a skill name") }
  end

  def test_skill_multiple_arguments_uses_first
    result = @instance.skill(['code-quality', 'extra-arg'])
    assert_equal "# Code Quality\nEnforce SOLID principles.", result
  end

  def test_skill_with_leading_trailing_whitespace
    result = @instance.skill(['  code-quality  '])
    assert_equal "# Code Quality\nEnforce SOLID principles.", result
  end

  # --- File system edge cases ---

  def test_skills_only_counts_directories
    # Add a regular file alongside skill directories
    File.write(File.join(@test_skills_dir, 'not-a-skill.txt'), 'just a file')
    create_skill('real-skill', '# Real Skill')

    @instance.skills
    output = @captured_stdout.string

    refute_includes output, 'not-a-skill.txt'
    assert_includes output, 'real-skill'
    assert_includes output, "Total: 5 skills"  # 4 original + real-skill
  end

  private

  def create_skill(name, content)
    skill_dir = File.join(@test_skills_dir, name)
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), content)
  end
end
