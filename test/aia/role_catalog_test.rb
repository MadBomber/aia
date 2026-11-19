require_relative '../test_helper'
require 'ostruct'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/aia'

class RoleCatalogTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('aia_roles')
    FileUtils.mkdir_p(File.join(@dir, 'roles', 'lang'))
    FileUtils.mkdir_p(File.join(@dir, 'roles', '_drafts'))
    File.write(File.join(@dir, 'roles', 'editor.md'), "---\ndescription: Tightens prose\n---\nYou edit.")
    File.write(File.join(@dir, 'roles', 'lang', 'ruby.md'), 'You know Ruby.')
    File.write(File.join(@dir, 'roles', '_drafts', 'wip.md'), 'Not ready.')
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_qualified_id
    assert_equal 'roles/editor', AIA::RoleCatalog.qualified_id('editor', 'roles')
    assert_equal 'roles/editor', AIA::RoleCatalog.qualified_id('roles/editor', 'roles')
    assert_equal './mine.md', AIA::RoleCatalog.qualified_id('./mine.md', 'roles')
    assert_equal 'editor', AIA::RoleCatalog.qualified_id('editor', '')
  end

  def test_role_file
    assert_equal File.join(@dir, 'roles/editor.md'), AIA::RoleCatalog.role_file('editor', dir: @dir, prefix: 'roles')
    assert_equal File.expand_path('~/r.md'), AIA::RoleCatalog.role_file('~/r', dir: @dir, prefix: 'roles')
  end

  def test_names_skip_private_entries
    assert_equal %w[editor lang/ruby], AIA::RoleCatalog.names(@dir, 'roles')
    assert_empty AIA::RoleCatalog.names('/nonexistent', 'roles')
  end

  def test_validate_passes_for_named_and_path_roles
    AIA::RoleCatalog.validate!('editor', dir: @dir, prefix: 'roles')
    AIA::RoleCatalog.validate!(File.join(@dir, 'roles', 'lang', 'ruby'), dir: '/elsewhere', prefix: 'roles')
  end

  def test_validate_missing_named_role_lists_available
    error = assert_raises(AIA::ConfigurationError) do
      AIA::RoleCatalog.validate!('nope', dir: @dir, prefix: 'roles')
    end
    assert_match(%r{Role file not found: .*roles/nope\.md}, error.message)
    assert_includes error.message, '  - editor'
  end

  def test_validate_missing_named_role_without_roles_dir
    Dir.mktmpdir do |empty|
      error = assert_raises(AIA::ConfigurationError) do
        AIA::RoleCatalog.validate!('nope', dir: empty, prefix: 'roles')
      end
      assert_includes error.message, 'No roles directory found'
    end
  end

  def test_validate_missing_path_role
    error = assert_raises(AIA::ConfigurationError) do
      AIA::RoleCatalog.validate!('/nonexistent/role', dir: @dir, prefix: 'roles')
    end
    assert_equal 'Role file not found: /nonexistent/role.md', error.message
  end

  def test_listing_shows_front_matter
    text = AIA::RoleCatalog.listing(@dir, 'roles')
    assert_includes text, '## editor'
    assert_includes text, '| description | Tightens prose |'
    assert_includes text, '## lang/ruby'
    refute_includes text, 'wip'
  end

  def test_listing_shows_dated_front_matter
    File.write(File.join(@dir, 'roles', 'dated.md'), "---\ndescription: Has a date\nupdated: 2026-01-15\n---\nHi.")
    text = AIA::RoleCatalog.listing(@dir, 'roles')
    assert_includes text, '| description | Has a date |'
    assert_includes text, '| updated | 2026-01-15 |'
  end

  def test_listing_without_roles
    assert_match(/No roles directory found/, AIA::RoleCatalog.listing('/nonexistent', 'roles'))
    Dir.mktmpdir do |empty|
      Dir.mkdir(File.join(empty, 'roles'))
      assert_match(/No role files found/, AIA::RoleCatalog.listing(empty, 'roles'))
    end
  end
end

class ConfiguredRolesTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('aia_roles')
    FileUtils.mkdir_p(File.join(@dir, 'roles'))
    File.write(File.join(@dir, 'roles', 'editor.md'), "---\ndescription: x\n---\nYou edit <%= 'carefully' %>.")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def config(**extra)
    OpenStruct.new(
      prompts: OpenStruct.new(dir: @dir, roles_prefix: 'roles', extname: '.md', role: nil, system_prompt: nil, skills: []),
      flags: OpenStruct.new(chat: false),
      models: [], **extra
    )
  end

  def test_list_roles_uses_the_configured_prompts_dir
    out, = capture_io do
      assert_equal :early_exit, AIA::ConfigValidator.send(:handle_list_roles, config(list_roles: true))
    end
    assert_includes out, '## editor'
  end

  def test_list_roles_not_requested
    assert_nil AIA::ConfigValidator.send(:handle_list_roles, config(list_roles: nil))
  end

  def test_model_roles_checked_against_the_configured_prompts_dir
    good = OpenStruct.new(name: 'gpt-4o', role: 'editor')
    AIA::ConfigValidator.send(:validate_model_roles, config(models: [good, OpenStruct.new(name: 'x', role: nil)]))

    bad = OpenStruct.new(name: 'gpt-4o', role: 'missing')
    error = assert_raises(AIA::ConfigurationError) do
      AIA::ConfigValidator.send(:validate_model_roles, config(models: [bad]))
    end
    assert_includes error.message, 'Role file not found'
  end

  def test_system_prompt_role_is_processed_like_a_prompt
    PM.configure { it.erb = true }
    assert_equal 'You edit carefully.', AIA::SystemPromptAssembler.load_role_content(config, 'editor')
  end

  def test_system_prompt_accepts_a_path_role
    path = File.join(@dir, 'elsewhere.md')
    File.write(path, "---\ndescription: y\n---\nYou review.")
    assert_equal 'You review.', AIA::SystemPromptAssembler.load_role_content(config, path.delete_suffix('.md'))
  end

  def test_system_prompt_missing_role_is_nil
    assert_nil AIA::SystemPromptAssembler.load_role_content(config, 'missing')
  end
end

class SkillsDirectoryWarningTest < Minitest::Test
  def test_named_skill_warns_when_skills_dir_is_missing
    _, err = capture_io do
      assert_nil AIA::SkillUtils.load_skills_content(['tidy'], '/nonexistent/skills')
    end
    assert_includes err, "Skill 'tidy' not loaded: skills directory \"/nonexistent/skills\" does not exist"
  end

  def test_path_skill_loads_without_a_skills_dir
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'tidy'))
      File.write(File.join(dir, 'tidy', 'SKILL.md'), "---\nname: tidy\n---\nKeep it tidy.")
      assert_equal 'Keep it tidy.', AIA::SkillUtils.load_skills_content([File.join(dir, 'tidy')], nil)
    end
  end
end
