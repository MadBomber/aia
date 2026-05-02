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

  def test_aia_skills_dir_returns_string
    AIA.stubs(:config).returns(nil)
    assert_kind_of String, @instance.send(:aia_skills_dir)
  ensure
    AIA.unstub(:config)
  end
end
