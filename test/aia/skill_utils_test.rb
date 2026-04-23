require_relative '../test_helper'
require 'fileutils'
require 'tmpdir'
require_relative '../../lib/aia/skill_utils'

class SkillUtilsTest < Minitest::Test
  # --- path_based_id? ---

  def test_absolute_path_is_path_based
    assert AIA::SkillUtils.path_based_id?('/usr/local/skills/foo')
  end

  def test_relative_dot_slash_is_path_based
    assert AIA::SkillUtils.path_based_id?('./my-skill')
  end

  def test_parent_relative_is_path_based
    assert AIA::SkillUtils.path_based_id?('../my-skill')
  end

  def test_tilde_path_is_path_based
    assert AIA::SkillUtils.path_based_id?('~/skills/foo')
  end

  def test_bare_name_is_not_path_based
    refute AIA::SkillUtils.path_based_id?('my-skill')
  end

  def test_empty_string_is_not_path_based
    refute AIA::SkillUtils.path_based_id?('')
  end

  # --- parse_front_matter ---

  def test_parses_valid_front_matter
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'test.md')
      File.write(path, "---\nname: Test\ndescription: A test skill\n---\n# Body")
      fm = AIA::SkillUtils.parse_front_matter(path)
      assert_equal 'Test', fm['name']
      assert_equal 'A test skill', fm['description']
    end
  end

  def test_returns_empty_hash_for_missing_file
    assert_equal({}, AIA::SkillUtils.parse_front_matter('/nonexistent/path.md'))
  end

  def test_returns_empty_hash_for_file_without_front_matter
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'no-fm.md')
      File.write(path, "# Just a body\n")
      assert_equal({}, AIA::SkillUtils.parse_front_matter(path))
    end
  end

  def test_returns_empty_hash_for_unclosed_front_matter
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'unclosed.md')
      File.write(path, "---\nname: Test\n")
      assert_equal({}, AIA::SkillUtils.parse_front_matter(path))
    end
  end

  def test_returns_empty_hash_on_invalid_yaml
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'bad.md')
      File.write(path, "---\n: invalid: yaml: [\n---\nbody")
      result = AIA::SkillUtils.parse_front_matter(path)
      assert_kind_of Hash, result
    end
  end

  # --- find_skill_dir ---

  def test_finds_exact_name_match
    Dir.mktmpdir do |base|
      skill_dir = File.join(base, 'my-skill')
      FileUtils.mkdir_p(skill_dir)
      result = AIA::SkillUtils.find_skill_dir('my-skill', base)
      assert_equal File.realpath(skill_dir), result
    end
  end

  def test_finds_prefix_match
    Dir.mktmpdir do |base|
      skill_dir = File.join(base, 'ruby-expert')
      FileUtils.mkdir_p(skill_dir)
      result = AIA::SkillUtils.find_skill_dir('ruby', base)
      assert_equal File.realpath(skill_dir), result
    end
  end

  def test_returns_nil_for_no_match
    Dir.mktmpdir do |base|
      assert_nil AIA::SkillUtils.find_skill_dir('nonexistent', base)
    end
  end

  def test_resolves_absolute_path_directly
    Dir.mktmpdir do |skill_dir|
      result = AIA::SkillUtils.find_skill_dir(skill_dir, '/some/base')
      assert_equal skill_dir, result
    end
  end

  def test_returns_nil_for_nonexistent_absolute_path
    assert_nil AIA::SkillUtils.find_skill_dir('/nonexistent/skill-path', '/base')
  end

  def test_blocks_symlink_traversal_outside_base
    outer = Dir.mktmpdir('outer_target')
    Dir.mktmpdir do |base|
      link = File.join(base, 'evil-link')
      File.symlink(outer, link)
      result = AIA::SkillUtils.find_skill_dir('evil-link', base)
      assert_nil result
    end
  ensure
    FileUtils.rm_rf(outer) if outer
  end

  # --- safe_skill_path ---

  def test_safe_path_within_base_returns_realpath
    Dir.mktmpdir do |base|
      child = File.join(base, 'skill')
      FileUtils.mkdir_p(child)
      result = AIA::SkillUtils.safe_skill_path(child, base)
      assert_equal File.realpath(child), result
    end
  end

  def test_safe_path_outside_base_returns_nil
    Dir.mktmpdir do |base|
      Dir.mktmpdir do |outside|
        assert_nil AIA::SkillUtils.safe_skill_path(outside, base)
      end
    end
  end

  def test_safe_path_nonexistent_returns_nil
    assert_nil AIA::SkillUtils.safe_skill_path('/nonexistent/path', '/base')
  end

  def test_safe_path_blocks_sibling_with_shared_prefix
    Dir.mktmpdir do |parent|
      base = File.join(parent, 'skills')
      attacker = File.join(parent, 'skills-attack')
      FileUtils.mkdir_p(base)
      FileUtils.mkdir_p(attacker)
      assert_nil AIA::SkillUtils.safe_skill_path(attacker, base)
    end
  end

  # --- include (instance method access) ---

  def test_methods_available_as_instance_methods_when_included
    klass = Class.new { include AIA::SkillUtils }
    obj = klass.new
    assert_respond_to obj, :path_based_id?
    assert_respond_to obj, :parse_front_matter
    assert_respond_to obj, :find_skill_dir
    assert_respond_to obj, :safe_skill_path
  end
end
