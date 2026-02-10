require_relative '../../test_helper'
require 'tempfile'

class DirectivesWebAndFileTest < Minitest::Test
  def setup
    @instance = AIA::WebAndFileDirectives.new
  end

  def test_webpage_returns_error_without_api_key
    if AIA::WebAndFileDirectives::PUREMD_API_KEY.nil?
      result = @instance.webpage(['http://example.com'])
      assert_includes result, 'ERROR'
      assert_includes result, 'PUREMD_API_KEY'
    end
  end

  def test_aliases_exist
    assert_respond_to @instance, :website
    assert_respond_to @instance, :web
    assert_respond_to @instance, :clipboard
  end

  def test_skills_dir_constant
    assert_kind_of String, AIA::WebAndFileDirectives::SKILLS_DIR
    assert AIA::WebAndFileDirectives::SKILLS_DIR.end_with?('.claude/skills')
  end
end
