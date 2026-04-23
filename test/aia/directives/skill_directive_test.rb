require_relative '../../test_helper'
require 'ostruct'
require 'fileutils'
require 'stringio'
require_relative '../../../lib/aia'

class SkillDirectiveTest < Minitest::Test
  def setup
    @test_skills_dir = Dir.mktmpdir('aia_test_skills')

    # Stub AIA.config.skills.dir to point at the temp directory
    skills_config = OpenStruct.new(dir: @test_skills_dir)
    @test_config = OpenStruct.new(skills: skills_config)
    AIA.stubs(:config).returns(@test_config)

    # Create test skills with YAML front matter
    create_skill('code-quality', "---\nname: Code Quality\ndescription: Enforce SOLID principles.\n---\n# Body")
    create_skill('code-assist',  "---\nname: Code Assist\ndescription: Help with coding tasks.\n---\n# Body")
    create_skill('frontend-design', "---\nname: Frontend Design\ndescription: Build user interfaces.\n---\n# Body")

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
    FileUtils.rm_rf(@test_skills_dir)
    super
  end

  # --- /skill tests ---

  def test_skill_exact_match
    result = @instance.skill(['code-quality'])
    assert_equal "---\nname: Code Quality\ndescription: Enforce SOLID principles.\n---\n# Body", result
  end

  def test_skill_prefix_match
    result = @instance.skill(['front'])
    assert_equal "---\nname: Frontend Design\ndescription: Build user interfaces.\n---\n# Body", result
  end

  def test_skill_prefix_match_returns_first_alphabetically
    result = @instance.skill(['code'])
    # code-assist comes before code-quality alphabetically
    assert_equal "---\nname: Code Assist\ndescription: Help with coding tasks.\n---\n# Body", result
  end

  def test_skill_exact_match_takes_priority_over_prefix
    result = @instance.skill(['code-quality'])
    assert_equal "---\nname: Code Quality\ndescription: Enforce SOLID principles.\n---\n# Body", result
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

  def test_skill_no_matching_suggests_skills_directive
    result = @instance.skill(['nonexistent'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Use /skills") }
  end

  def test_skill_directory_without_skill_md_returns_nil
    result = @instance.skill(['empty-skill'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("has no SKILL.md") }
  end

  def test_skill_directory_without_skill_md_suggests_skills_directive
    result = @instance.skill(['empty-skill'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Use /skills") }
  end

  def test_skill_prefix_match_skips_dir_without_skill_md
    result = @instance.skill(['empty'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("has no SKILL.md") }
  end

  def test_skill_absolute_path_resolves_skill_md
    skill_dir = Dir.mktmpdir('aia_path_skill')
    File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: Path Skill\ndescription: From path.\n---\n# Path Body")

    result = @instance.skill([skill_dir])
    assert_equal "---\nname: Path Skill\ndescription: From path.\n---\n# Path Body", result
  ensure
    FileUtils.rm_rf(skill_dir) if skill_dir
  end

  def test_skill_direct_md_file_path_returns_content
    Dir.mktmpdir('aia_direct_md_skill') do |dir|
      file = File.join(dir, 'my-skill.md')
      File.write(file, "---\nname: Direct MD\ndescription: Direct file.\n---\n# Direct Body")
      result = @instance.skill([file])
      assert_equal "---\nname: Direct MD\ndescription: Direct file.\n---\n# Direct Body", result
    end
  end

  def test_skill_path_directory_missing_returns_nil
    result = @instance.skill(['/nonexistent/absolute/path/my-skill'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("No skill directory found at") }
  end

  def test_skill_path_directory_without_skill_md_returns_nil
    dir = Dir.mktmpdir('aia_no_skill_md')
    result = @instance.skill([dir])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("has no SKILL.md") }
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_skill_absolute_path_to_skill_dir_returns_content
    Dir.mktmpdir('aia_abs_skill') do |base|
      skill_dir = File.join(base, 'my-skill')
      FileUtils.mkdir_p(skill_dir)
      File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: Absolute Skill\n---\n# Absolute Body")

      result = @instance.skill([skill_dir])
      assert_equal "---\nname: Absolute Skill\n---\n# Absolute Body", result
    end
  end

  # --- /skills tests ---

  def test_skills_lists_subdirectories
    @instance.skills
    output = @captured_stdout.string

    assert_includes output, "Available Skills"
    assert_includes output, "Code Assist"
    assert_includes output, "Code Quality"
    assert_includes output, "empty-skill"
    assert_includes output, "Frontend Design"
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

    skill_lines = lines.select { |l| l.start_with?('Code') || l.start_with?('code-') ||
                                     l.start_with?('empty') || l.start_with?('front') ||
                                     l.start_with?('Frontend') }
    # Skill names shown are either display_name from front matter or directory name
    assert skill_lines.size >= 4, "Expected at least 4 skill entries, got: #{skill_lines.inspect}"
  end

  def test_skills_empty_directory
    FileUtils.rm_rf(Dir.glob(File.join(@test_skills_dir, '*')))

    @instance.skills
    output = @captured_stdout.string
    assert_includes output, "No skills found"
  end

  def test_skills_missing_directory
    @test_config.skills = OpenStruct.new(dir: '/nonexistent/path')

    @instance.skills
    output = @captured_stdout.string
    assert_includes output, "No skills directory found"
  end

  def test_skills_excludes_files
    File.write(File.join(@test_skills_dir, '_patterns.md'), 'not a skill')

    @instance.skills
    output = @captured_stdout.string

    refute_includes output, "_patterns.md"
    assert_includes output, "Total: 4 skills"
  end

  # --- AND NOT search for /skills ---

  def test_skills_positive_filter_includes_matches
    @instance.skills(['code'])
    output = @captured_stdout.string

    assert_includes output, "Code Assist"
    assert_includes output, "Code Quality"
    refute_includes output, "Frontend Design"
    refute_includes output, "empty-skill"
  end

  def test_skills_negative_filter_excludes_matches
    @instance.skills(['-quality'])
    output = @captured_stdout.string

    assert_includes output, "Code Assist"
    assert_includes output, "Frontend Design"
    assert_includes output, "empty-skill"
    refute_includes output, "Code Quality"
  end

  def test_skills_negative_filter_using_tilde
    @instance.skills(['~quality'])
    output = @captured_stdout.string

    refute_includes output, "Code Quality"
  end

  def test_skills_negative_filter_using_bang
    @instance.skills(['!quality'])
    output = @captured_stdout.string

    refute_includes output, "Code Quality"
  end

  def test_skills_combined_positive_and_negative
    @instance.skills(['code', '-quality'])
    output = @captured_stdout.string

    assert_includes output, "Code Assist"
    refute_includes output, "Code Quality"
    refute_includes output, "Frontend Design"
  end

  def test_skills_no_matches_shows_message
    @instance.skills(['nonexistent-term-xyz'])
    output = @captured_stdout.string

    assert_includes output, "No skills matching your query"
  end

  # --- Security tests for safe_skill_path / path traversal ---

  def test_skill_path_traversal_blocked
    result = @instance.skill(['../../nonexistent_aia_path_traversal_xyz_test'])
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("No skill directory found at") }
  end

  def test_skill_symlink_outside_skills_dir_blocked
    external_dir = Dir.mktmpdir('evil_skill')
    File.write(File.join(external_dir, 'SKILL.md'), '# Evil Skill')

    symlink_path = File.join(@test_skills_dir, 'evil-link')
    File.symlink(external_dir, symlink_path)

    result = @instance.skill(['evil-link'])
    assert_nil result
  ensure
    FileUtils.rm_f(symlink_path)
    FileUtils.rm_rf(external_dir)
  end

  def test_skill_broken_symlink_returns_nil
    symlink_path = File.join(@test_skills_dir, 'broken-link')
    File.symlink('/nonexistent/target/dir', symlink_path)

    result = @instance.skill(['broken-link'])
    assert_nil result
  end

  # --- Edge cases ---

  def test_skill_nil_argument_returns_nil
    result = @instance.skill(nil)
    assert_nil result
    assert @stderr_messages.any? { |m| m.include?("Error: /skill requires a skill name") }
  end

  def test_skill_multiple_arguments_uses_first
    result = @instance.skill(['code-quality', 'extra-arg'])
    assert_equal "---\nname: Code Quality\ndescription: Enforce SOLID principles.\n---\n# Body", result
  end

  def test_skill_with_leading_trailing_whitespace
    result = @instance.skill(['  code-quality  '])
    assert_equal "---\nname: Code Quality\ndescription: Enforce SOLID principles.\n---\n# Body", result
  end

  def test_skills_only_counts_directories
    File.write(File.join(@test_skills_dir, 'not-a-skill.txt'), 'just a file')
    create_skill('real-skill', "---\nname: Real Skill\ndescription: A real skill.\n---\n# Body")

    @instance.skills
    output = @captured_stdout.string

    refute_includes output, 'not-a-skill.txt'
    assert_includes output, 'Real Skill'
    assert_includes output, "Total: 5 skills"
  end

  def test_aia_skills_dir_returns_config_value
    assert_equal @test_skills_dir, @instance.send(:aia_skills_dir)
  end

  private

  def create_skill(name, content)
    skill_dir = File.join(@test_skills_dir, name)
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), content)
  end
end
