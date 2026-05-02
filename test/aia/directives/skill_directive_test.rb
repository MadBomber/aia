require_relative '../../test_helper'
require 'ostruct'
require 'fileutils'
require 'stringio'
require_relative '../../../lib/aia'

class SkillDirectiveTest < Minitest::Test
  def setup
    @test_skills_dir = Dir.mktmpdir('aia_test_skills')

    create_skill('code-quality',    'Code Quality',    'Enforce SOLID principles.')
    create_skill('code-assist',     'Code Assist',     'Help with coding tasks.')
    create_skill('frontend-design', 'Frontend Design', 'Build interfaces.')

    # Skill directory without SKILL.md
    FileUtils.mkdir_p(File.join(@test_skills_dir, 'empty-skill'))

    @instance = AIA::WebAndFileDirectives.new
    @instance.stubs(:aia_skills_dir).returns(@test_skills_dir)

    @original_stdout = $stdout
    @captured_stdout = StringIO.new
    $stdout = @captured_stdout

    @stderr_messages = []
    @instance.stubs(:warn).with { |msg| @stderr_messages << msg; true }

    mock_logger = stub('logger', error: nil, warn: nil, info: nil, debug: nil)
    AIA::LoggerManager.stubs(:aia_logger).returns(mock_logger)
  end

  def teardown
    $stdout = @original_stdout
    FileUtils.rm_rf(@test_skills_dir)
    super
  end

  # --- /skill tests ---

  def test_skill_exact_match
    result = @instance.skill(['code-quality'])
    assert_includes result, 'name: Code Quality'
    assert_includes result, 'description: Enforce SOLID principles.'
  end

  def test_skill_prefix_match
    result = @instance.skill(['front'])
    assert_includes result, 'name: Frontend Design'
  end

  def test_skill_prefix_match_returns_first_alphabetically
    result = @instance.skill(['code'])
    # code-assist comes before code-quality alphabetically
    assert_includes result, 'name: Code Assist'
  end

  def test_skill_exact_match_takes_priority_over_prefix
    result = @instance.skill(['code-quality'])
    assert_includes result, 'name: Code Quality'
    refute_includes result, 'Code Assist'
  end

  def test_skill_no_argument_returns_nil
    result = @instance.skill([])
    assert_nil result
    assert_match(/Error: \/skill requires a skill name/, @captured_stdout.string)
  end

  def test_skill_empty_argument_returns_nil
    result = @instance.skill(['  '])
    assert_nil result
    assert_match(/Error: \/skill requires a skill name/, @captured_stdout.string)
  end

  def test_skill_no_matching_directory_returns_nil
    result = @instance.skill(['nonexistent'])
    assert_nil result
    assert_match(/No skill matching 'nonexistent'/, @captured_stdout.string)
  end

  def test_skill_directory_without_skill_md_returns_nil
    result = @instance.skill(['empty-skill'])
    assert_nil result
    assert_match(/has no SKILL\.md/, @captured_stdout.string)
  end

  def test_skill_prefix_match_skips_dir_without_skill_md
    result = @instance.skill(['empty'])
    assert_nil result
    assert_match(/has no SKILL\.md/, @captured_stdout.string)
  end

  # --- /skills tests ---

  def test_skills_lists_skill_id_and_name
    @instance.skills
    output = @captured_stdout.string

    assert_match(/^code-assist: Code Assist$/, output)
    assert_match(/^code-quality: Code Quality$/, output)
    assert_match(/^frontend-design: Frontend Design$/, output)
  end

  def test_skills_lists_description_indented
    @instance.stubs(:terminal_width).returns(80)
    @instance.skills
    output = @captured_stdout.string

    assert_match(/^  Help with coding tasks\.$/, output)
    assert_match(/^  Enforce SOLID principles\.$/, output)
  end

  def test_skills_wraps_long_description
    @instance.stubs(:terminal_width).returns(30)
    create_skill('long-desc', 'Long', 'This is a very long description that should be wrapped at thirty characters.')

    @instance.skills(['long'])
    output = @captured_stdout.string

    lines = output.lines.select { |l| l.start_with?('  ') }.map(&:chomp)
    assert lines.size > 1, "Expected description to wrap onto multiple lines"
    lines.each { |l| assert l.start_with?('  '), "Each wrapped line must be indented" }
    lines.each { |l| assert l.length <= 32, "No line should exceed width+indent (#{l.inspect})" }
  end

  def test_skills_returns_nil
    result = @instance.skills
    assert_nil result
  end

  def test_skills_sorted_alphabetically
    @instance.skills
    output = @captured_stdout.string
    id_lines = output.lines.select { |l| l =~ /^\w/ }.map(&:chomp)

    assert_equal ['code-assist: Code Assist',
                  'code-quality: Code Quality',
                  'frontend-design: Frontend Design'], id_lines
  end

  def test_skills_only_lists_dirs_with_skill_md
    @instance.skills
    output = @captured_stdout.string
    refute_match(/^empty-skill/, output)
  end

  def test_skills_empty_directory
    FileUtils.rm_rf(Dir.glob(File.join(@test_skills_dir, '*')))

    @instance.skills
    output = @captured_stdout.string
    assert_includes output, "No skills found"
  end

  def test_skills_missing_directory
    @instance.stubs(:aia_skills_dir).returns('/nonexistent/path')

    @instance.skills
    output = @captured_stdout.string
    assert_includes output, "No skills directory found"
  end

  def test_skills_excludes_plain_files
    File.write(File.join(@test_skills_dir, '_patterns.md'), 'not a skill')

    @instance.skills
    output = @captured_stdout.string
    refute_includes output, "_patterns.md"
  end

  # --- /skills search filtering ---

  def test_skills_with_single_term_filters_results
    create_skill('ruby-style',   'Ruby Style',   'Enforce Ruby coding style guidelines.')
    create_skill('python-style', 'Python Style', 'Enforce Python coding style guidelines.')

    @instance.skills(['ruby'])
    output = @captured_stdout.string

    assert_match(/^ruby-style:/, output)
    refute_match(/^python-style:/, output)
  end

  def test_skills_with_multiple_terms_requires_all
    create_skill('ruby-testing',  'Ruby Testing',  'Write Ruby tests with minitest.')
    create_skill('ruby-style',    'Ruby Style',    'Enforce Ruby coding style.')
    create_skill('python-testing','Python Testing','Write Python tests with pytest.')

    @instance.skills(['ruby', 'test'])
    output = @captured_stdout.string

    assert_match(/^ruby-testing:/, output)
    refute_match(/^ruby-style:/, output)
    refute_match(/^python-testing:/, output)
  end

  def test_skills_search_is_case_insensitive
    create_skill('arch-skill', 'Architecture', 'Ruby architecture patterns.')

    @instance.skills(['RUBY', 'ARCH'])
    output = @captured_stdout.string

    assert_match(/^arch-skill:/, output)
  end

  def test_skills_plus_prefix_is_treated_as_positive
    create_skill('ruby-testing', 'Ruby Testing', 'Write Ruby tests.')
    create_skill('python-style', 'Python Style', 'Python coding style.')

    @instance.skills(['+ruby'])
    output = @captured_stdout.string

    assert_match(/^ruby-testing:/, output)
    refute_match(/^python-style:/, output)
  end

  def test_skills_minus_prefix_excludes_matches
    create_skill('ruby-testing', 'Ruby Testing', 'Write Ruby tests.')
    create_skill('ruby-style',   'Ruby Style',   'Ruby coding style.')

    @instance.skills(['ruby', '-test'])
    output = @captured_stdout.string

    assert_match(/^ruby-style:/, output)
    refute_match(/^ruby-testing:/, output)
  end

  def test_skills_tilde_prefix_excludes_matches
    create_skill('ruby-testing', 'Ruby Testing', 'Write Ruby tests.')
    create_skill('ruby-style',   'Ruby Style',   'Ruby coding style.')

    @instance.skills(['ruby', '~test'])
    output = @captured_stdout.string

    assert_match(/^ruby-style:/, output)
    refute_match(/^ruby-testing:/, output)
  end

  def test_skills_bang_prefix_excludes_matches
    create_skill('ruby-testing', 'Ruby Testing', 'Write Ruby tests.')
    create_skill('ruby-style',   'Ruby Style',   'Ruby coding style.')

    @instance.skills(['ruby', '!test'])
    output = @captured_stdout.string

    assert_match(/^ruby-style:/, output)
    refute_match(/^ruby-testing:/, output)
  end

  def test_skills_negative_only_excludes_from_all
    create_skill('ruby-testing', 'Ruby Testing', 'Write Ruby tests.')
    create_skill('ruby-style',   'Ruby Style',   'Ruby coding style.')

    @instance.skills(['-test'])
    output = @captured_stdout.string

    assert_match(/^code-assist:/, output)
    assert_match(/^ruby-style:/, output)
    refute_match(/^ruby-testing:/, output)
  end

  def test_skills_no_match_prints_message
    @instance.skills(['zzznomatch'])
    output = @captured_stdout.string

    assert_match(/No skills matched/, output)
    assert_match(/zzznomatch/, output)
  end

  def test_skills_with_no_args_lists_all
    @instance.skills([])
    output = @captured_stdout.string

    assert_match(/^code-assist:/, output)
    assert_match(/^code-quality:/, output)
    assert_match(/^frontend-design:/, output)
  end

  def test_skills_falls_back_to_empty_string_when_no_name_in_front_matter
    Dir.mkdir(File.join(@test_skills_dir, 'no-name'))
    File.write(File.join(@test_skills_dir, 'no-name', 'SKILL.md'), <<~MD)
      ---
      description: Only a description, no name key.
      ---
    MD

    @instance.skills
    output = @captured_stdout.string
    assert_match(/^no-name: $/, output)
    assert_match(/^  Only a description, no name key\.$/, output)
  end

  # --- Security tests for safe_skill_path / path traversal ---

  def test_skill_path_traversal_blocked
    result = @instance.skill(['../../etc'])
    assert_nil result
    assert_match(/No skill matching/, @captured_stdout.string)
  end

  def test_skill_symlink_outside_skills_dir_blocked
    external_dir = Dir.mktmpdir('evil_skill')
    File.write(File.join(external_dir, 'SKILL.md'), '# Evil Skill')

    symlink_path = File.join(@test_skills_dir, 'evil-link')
    File.symlink(external_dir, symlink_path)

    result = @instance.skill(['evil-link'])
    assert_nil result
  ensure
    FileUtils.rm_rf(external_dir)
  end

  def test_skill_symlink_to_sibling_with_same_prefix_is_blocked
    external_dir = "#{@test_skills_dir}_evil"
    FileUtils.mkdir_p(external_dir)
    File.write(File.join(external_dir, 'SKILL.md'), '# Evil Prefix Skill')

    symlink_path = File.join(@test_skills_dir, 'evil-prefix-link')
    File.symlink(external_dir, symlink_path)

    result = @instance.skill(['evil-prefix-link'])
    assert_nil result
  ensure
    FileUtils.rm_rf(external_dir) if external_dir
  end

  def test_skill_broken_symlink_returns_nil
    symlink_path = File.join(@test_skills_dir, 'broken-link')
    File.symlink('/nonexistent/target/dir', symlink_path)

    result = @instance.skill(['broken-link'])
    assert_nil result
  end

  # --- aia_skills_dir resolution ---

  def test_aia_skills_dir_uses_aia_config_when_available
    instance = AIA::WebAndFileDirectives.new
    config = OpenStruct.new(skills: OpenStruct.new(dir: '/custom/skills'))
    AIA.stubs(:config).returns(config)
    assert_equal '/custom/skills', instance.send(:aia_skills_dir)
  ensure
    AIA.unstub(:config)
  end

  def test_aia_skills_dir_falls_back_to_env_vars
    instance = AIA::WebAndFileDirectives.new
    AIA.stubs(:config).returns(nil)
    ENV['AIA_PROMPTS__DIR']           = '/env/prompts'
    ENV['AIA_PROMPTS__SKILLS_PREFIX'] = 'my_skills'
    assert_equal '/env/prompts/my_skills', instance.send(:aia_skills_dir)
  ensure
    AIA.unstub(:config)
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__SKILLS_PREFIX')
  end

  # --- Edge cases ---

  def test_skill_nil_argument_returns_nil
    result = @instance.skill(nil)
    assert_nil result
    assert_match(/Error: \/skill requires a skill name/, @captured_stdout.string)
  end

  def test_skill_multiple_arguments_uses_first
    result = @instance.skill(['code-quality', 'extra-arg'])
    assert_includes result, 'name: Code Quality'
  end

  def test_skill_with_leading_trailing_whitespace
    result = @instance.skill(['  code-quality  '])
    assert_includes result, 'name: Code Quality'
  end

  def test_skills_only_lists_dirs_with_skill_md_not_plain_files
    File.write(File.join(@test_skills_dir, 'not-a-skill.txt'), 'just a file')
    create_skill('real-skill', 'Real Skill', 'Does real things.')

    @instance.skills
    output = @captured_stdout.string

    refute_includes output, 'not-a-skill.txt'
    assert_match(/^real-skill:/, output)
  end

  private

  def create_skill(id, name, description, body = nil)
    skill_dir = File.join(@test_skills_dir, id)
    FileUtils.mkdir_p(skill_dir)
    content = "---\nname: #{name}\ndescription: #{description}\n---\n"
    content += "\n#{body}" if body
    File.write(File.join(skill_dir, 'SKILL.md'), content)
  end
end
