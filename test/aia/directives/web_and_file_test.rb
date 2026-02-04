require_relative '../../test_helper'
require 'tempfile'

class DirectivesWebAndFileTest < Minitest::Test
  def setup
    # Reset included files tracking between tests
    AIA::Directives::WebAndFile.included_files = []
  end

  def test_include_file_reads_existing_file
    Tempfile.create(['test_include', '.txt']) do |f|
      f.write("file content here")
      f.flush

      result = AIA::Directives::WebAndFile.include_file(f.path)
      assert_equal "file content here", result
    end
  end

  def test_include_file_returns_error_for_missing_file
    result = AIA::Directives::WebAndFile.include_file('/nonexistent/file.txt')
    assert_includes result, "Error"
    assert_includes result, "not accessible"
  end

  def test_include_file_prevents_duplicate_includes
    Tempfile.create(['test_dup', '.txt']) do |f|
      f.write("content")
      f.flush

      first_result = AIA::Directives::WebAndFile.include_file(f.path)
      assert_equal "content", first_result

      second_result = AIA::Directives::WebAndFile.include_file(f.path)
      assert_equal '', second_result
    end
  end

  def test_included_files_tracks_files
    Tempfile.create(['test_track', '.txt']) do |f|
      f.write("content")
      f.flush

      AIA::Directives::WebAndFile.include_file(f.path)
      assert_includes AIA::Directives::WebAndFile.included_files, f.path
    end
  end

  def test_included_files_setter
    AIA::Directives::WebAndFile.included_files = ['a.txt', 'b.txt']
    assert_equal ['a.txt', 'b.txt'], AIA::Directives::WebAndFile.included_files
  end

  def test_included_files_default_empty
    AIA::Directives::WebAndFile.included_files = nil
    files = AIA::Directives::WebAndFile.included_files
    assert_equal [], files
  end

  def test_webpage_returns_error_without_api_key
    # PUREMD_API_KEY is likely not set in test environment
    original = ENV['PUREMD_API_KEY']
    ENV.delete('PUREMD_API_KEY')

    # Reload the constant since it's set at load time
    # Instead, test the method behavior when key is nil
    if AIA::Directives::WebAndFile::PUREMD_API_KEY.nil?
      result = AIA::Directives::WebAndFile.webpage(['http://example.com'])
      assert_includes result, 'ERROR'
      assert_includes result, 'PUREMD_API_KEY'
    end
  ensure
    ENV['PUREMD_API_KEY'] = original if original
  end

  def test_aliases_exist
    assert_respond_to AIA::Directives::WebAndFile, :website
    assert_respond_to AIA::Directives::WebAndFile, :web
    assert_respond_to AIA::Directives::WebAndFile, :import
    assert_respond_to AIA::Directives::WebAndFile, :clipboard
  end

  def test_skills_dir_constant
    assert_kind_of String, AIA::Directives::WebAndFile::SKILLS_DIR
    assert AIA::Directives::WebAndFile::SKILLS_DIR.end_with?('.claude/skills')
  end
end
