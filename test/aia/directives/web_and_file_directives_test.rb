# frozen_string_literal: true

# test/aia/directives/web_and_file_directives_test.rb
#
# Coverage for AIA::WebAndFileDirectives
# R5 (reliability) + SE2 (security — path traversal guard in safe_skill_path)

require_relative '../../test_helper'
require 'tmpdir'
require 'fileutils'
require 'ostruct'

class WebAndFileDirectivesTest < Minitest::Test
  def setup
    @instance = AIA::WebAndFileDirectives.new

    # Redirect stdout so puts-based output doesn't pollute test output
    @original_stdout = $stdout
    @captured_stdout = StringIO.new
    $stdout = @captured_stdout

    # Capture warn calls (stderr)
    @stderr_messages = []
    @instance.stubs(:warn).with { |msg| @stderr_messages << msg; true }

    # Stub AIA::LoggerManager so skill / skills methods don't blow up
    mock_logger = stub('logger',
      error: nil,
      warn: nil,
      info: nil,
      debug: nil
    )
    AIA::LoggerManager.stubs(:aia_logger).returns(mock_logger)
  end

  def teardown
    $stdout = @original_stdout
    super
  end

  # ---------------------------------------------------------------------------
  # /paste — reads from system clipboard
  # ---------------------------------------------------------------------------

  def test_paste_returns_clipboard_content
    Clipboard.stubs(:paste).returns('hello world')
    result = @instance.paste
    assert_equal 'hello world', result
  end

  def test_paste_returns_empty_string_when_clipboard_empty
    Clipboard.stubs(:paste).returns('')
    result = @instance.paste
    assert_equal '', result
  end

  def test_paste_returns_nil_as_empty_string
    Clipboard.stubs(:paste).returns(nil)
    result = @instance.paste
    assert_equal '', result
  end

  def test_paste_returns_error_string_when_clipboard_raises
    Clipboard.stubs(:paste).raises(StandardError, 'clipboard unavailable')
    result = @instance.paste
    assert_match(/Error:.*Unable to paste/, result)
    assert_match(/clipboard unavailable/, result)
  end

  def test_paste_does_not_raise_on_clipboard_error
    Clipboard.stubs(:paste).raises(RuntimeError, 'no display')
    result = @instance.paste
    assert_kind_of String, result
    assert_match(/Error/, result)
  end

  def test_clipboard_alias_exists
    assert_respond_to @instance, :clipboard
  end

  def test_clipboard_alias_calls_paste
    Clipboard.stubs(:paste).returns('clipped')
    assert_equal @instance.paste, @instance.clipboard
  end

  # ---------------------------------------------------------------------------
  # /webpage — requires PUREMD_API_KEY
  # ---------------------------------------------------------------------------

  def test_webpage_returns_error_when_api_key_missing
    stub_const(AIA::WebAndFileDirectives, :PUREMD_API_KEY, nil) do
      result = @instance.webpage(['http://example.com'])
      assert_match(/ERROR/, result)
      assert_match(/PUREMD_API_KEY/, result)
    end
  end

  def test_webpage_fetches_url_when_api_key_present
    stub_const(AIA::WebAndFileDirectives, :PUREMD_API_KEY, 'test-key') do
      mock_response = stub('response', status: 200, body: '# Page Content')
      Faraday.stubs(:get).returns(mock_response)
      result = @instance.webpage(['http://example.com'])
      assert_equal '# Page Content', result
    end
  end

  def test_webpage_returns_error_on_non_200_status
    stub_const(AIA::WebAndFileDirectives, :PUREMD_API_KEY, 'test-key') do
      mock_response = stub('response', status: 404, body: 'Not Found')
      # ap is called in the error branch; stub it to avoid output
      @instance.stubs(:ap).returns(mock_response)
      Faraday.stubs(:get).returns(mock_response)
      result = @instance.webpage(['http://example.com'])
      assert_match(/404/, result)
    end
  end

  def test_web_alias_exists
    assert_respond_to @instance, :web
  end

  def test_website_alias_exists
    assert_respond_to @instance, :website
  end

  # ---------------------------------------------------------------------------
  # /skills — directory listing
  # ---------------------------------------------------------------------------

  def test_skills_returns_nil_when_directory_missing
    with_skills_dir('/nonexistent/path/that/does/not/exist') do
      result = @instance.skills
      assert_nil result
      assert_match(/No skills directory/, @captured_stdout.string)
    end
  end

  def test_skills_returns_nil_always
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      create_skill(tmpdir, 'my-skill', '# My Skill')
      with_skills_dir(tmpdir) do
        result = @instance.skills
        assert_nil result
      end
    end
  end

  def test_skills_lists_subdirectories
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      create_skill(tmpdir, 'alpha-skill', '# Alpha')
      create_skill(tmpdir, 'beta-skill', '# Beta')
      with_skills_dir(tmpdir) do
        @instance.skills
        out = @captured_stdout.string
        assert_includes out, 'alpha-skill'
        assert_includes out, 'beta-skill'
        assert_includes out, 'Total: 2 skills'
      end
    end
  end

  def test_skills_excludes_regular_files
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      create_skill(tmpdir, 'real-skill', '# Real')
      File.write(File.join(tmpdir, 'not-a-skill.md'), 'just a file')
      with_skills_dir(tmpdir) do
        @instance.skills
        out = @captured_stdout.string
        refute_includes out, 'not-a-skill.md'
        assert_includes out, 'Total: 1 skills'
      end
    end
  end

  def test_skills_prints_no_skills_message_for_empty_dir
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      with_skills_dir(tmpdir) do
        @instance.skills
        assert_match(/No skills found/, @captured_stdout.string)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # /skill — loads SKILL.md content
  # ---------------------------------------------------------------------------

  def test_skill_returns_nil_for_empty_name
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      with_skills_dir(tmpdir) do
        result = @instance.skill([])
        assert_nil result
        assert @stderr_messages.any? { |m| m.include?('requires a skill name') }
      end
    end
  end

  def test_skill_returns_nil_for_whitespace_name
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      with_skills_dir(tmpdir) do
        result = @instance.skill(['   '])
        assert_nil result
        assert @stderr_messages.any? { |m| m.include?('requires a skill name') }
      end
    end
  end

  def test_skill_reads_skill_md_content
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      create_skill(tmpdir, 'my-skill', '# My Skill Content')
      with_skills_dir(tmpdir) do
        result = @instance.skill(['my-skill'])
        assert_equal '# My Skill Content', result
      end
    end
  end

  def test_skill_returns_nil_when_skill_not_found
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      with_skills_dir(tmpdir) do
        result = @instance.skill(['nonexistent'])
        assert_nil result
        assert @stderr_messages.any? { |m| m.include?("No skill matching 'nonexistent'") }
      end
    end
  end

  def test_skill_returns_nil_when_no_skill_md_file
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      # Create skill dir without SKILL.md
      FileUtils.mkdir_p(File.join(tmpdir, 'empty-skill'))
      with_skills_dir(tmpdir) do
        result = @instance.skill(['empty-skill'])
        assert_nil result
        assert @stderr_messages.any? { |m| m.include?('has no SKILL.md') }
      end
    end
  end

  # ---------------------------------------------------------------------------
  # SE2 — Security: safe_skill_path path traversal guard
  # ---------------------------------------------------------------------------

  def test_safe_skill_path_blocks_path_traversal_sequence
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      with_skills_dir(tmpdir) do
        # Attempt path traversal via skill name
        result = @instance.skill(['../../etc/passwd'])
        assert_nil result,
          'Path traversal via ../../etc/passwd must be blocked and return nil'
      end
    end
  end

  def test_safe_skill_path_blocks_absolute_path_outside_skills_dir
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      with_skills_dir(tmpdir) do
        # Try to reference /tmp directly (outside SKILLS_DIR)
        result = @instance.skill(['/tmp'])
        assert_nil result,
          'Absolute path outside SKILLS_DIR must be blocked'
      end
    end
  end

  def test_safe_skill_path_returns_resolved_path_for_valid_skill
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      create_skill(tmpdir, 'valid-skill', '# Valid')
      with_skills_dir(tmpdir) do
        # safe_skill_path is private; test it through the public skill method
        result = @instance.skill(['valid-skill'])
        assert_equal '# Valid', result,
          'A valid skill inside SKILLS_DIR must be read successfully'
      end
    end
  end

  def test_safe_skill_path_blocks_symlink_pointing_outside_skills_dir
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      Dir.mktmpdir('aia_evil_external') do |evil_dir|
        File.write(File.join(evil_dir, 'SKILL.md'), '# Evil Content')
        symlink = File.join(tmpdir, 'evil-link')
        File.symlink(evil_dir, symlink)

        with_skills_dir(tmpdir) do
          result = @instance.skill(['evil-link'])
          assert_nil result,
            'Symlink pointing outside SKILLS_DIR must be blocked by safe_skill_path'
        end
      end
    end
  end

  def test_safe_skill_path_handles_broken_symlink_gracefully
    Dir.mktmpdir('aia_skills_test') do |tmpdir|
      symlink = File.join(tmpdir, 'broken-link')
      File.symlink('/nonexistent/path', symlink)

      with_skills_dir(tmpdir) do
        result = @instance.skill(['broken-link'])
        assert_nil result,
          'Broken symlink must return nil without raising'
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  def test_skills_dir_constant_is_string
    assert_kind_of String, AIA::WebAndFileDirectives::SKILLS_DIR
  end

  def test_skills_dir_constant_points_to_claude_skills
    assert AIA::WebAndFileDirectives::SKILLS_DIR.end_with?('.claude/skills'),
      "SKILLS_DIR should end with '.claude/skills'"
  end

  private

  # Helper: temporarily override SKILLS_DIR and yield
  def with_skills_dir(path)
    original = AIA::WebAndFileDirectives::SKILLS_DIR
    AIA::WebAndFileDirectives.send(:remove_const, :SKILLS_DIR)
    AIA::WebAndFileDirectives.const_set(:SKILLS_DIR, path)
    yield
  ensure
    AIA::WebAndFileDirectives.send(:remove_const, :SKILLS_DIR)
    AIA::WebAndFileDirectives.const_set(:SKILLS_DIR, original)
  end

  # Helper: temporarily override any constant on a class and yield
  def stub_const(klass, const_name, value)
    original = klass.const_get(const_name)
    klass.send(:remove_const, const_name)
    klass.const_set(const_name, value)
    yield
  ensure
    klass.send(:remove_const, const_name)
    klass.const_set(const_name, original)
  end

  # Helper: create a skill directory with SKILL.md
  def create_skill(base_dir, name, content)
    skill_dir = File.join(base_dir, name)
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), content)
  end
end
