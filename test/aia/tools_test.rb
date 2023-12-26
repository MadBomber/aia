# test/aia/tools_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia/tools'

class ToolsTest < Minitest::Test
  def test_initialize
    tool = AIA::Tools.new

    assert_equal :role,                 tool.role
    assert_equal "tools",               tool.name
    assert_equal "description",         tool.description
    assert_equal "URL",                 tool.url
    assert_equal "brew install tools",  tool.install
  end


  def test_installed_query
    tool = AIA::Tools.new
    tool.stub :name, "echo" do
      assert tool.installed?
    end
  end


  def test_help
    tool      = AIA::Tools.new
    tool.name = "ruby"
    help_text = tool.help.downcase

    assert help_text.include?('usage')
    assert help_text.include?('ruby')
  end


  def test_version
    tool          = AIA::Tools.new
    tool.name     = 'ruby'
    version_text  = tool.version.downcase
    ruby_version  = RUBY_VERSION

    assert version_text.start_with?("ruby #{RUBY_VERSION}")
  end


  def test_verify_tools
    AIA::Tools.stub :verify_tools, nil do
      assert_nil AIA::Tools.verify_tools
    end
  end


  def test_format_missing_tools_response
    fake_tool = Minitest::Mock.new
    fake_tool.expect :name, 'fake'
    fake_tool.expect :url, 'https://example.com/fake'

    expected_response = <<EOS

WARNING: AIA makes use of external CLI tools that are missing.

Please install the following tools:

  fake: install from https://example.com/fake
EOS

    assert_equal expected_response, AIA::Tools.format_missing_tools_response([fake_tool])
  end
end
