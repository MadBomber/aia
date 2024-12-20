# test/aia/dynamic_content_test.rb

require 'test_helper'

class DynamicContentTest < Minitest::Test
  class TestClass
    include AIA::DynamicContent
  end

  def setup
    @subject = TestClass.new
  end

  def test_render_env_with_simple_variable
    ENV['TEST_VAR'] = 'hello'
    assert_equal 'hello', @subject.render_env('$TEST_VAR')
    assert_equal 'hello', @subject.render_env('${TEST_VAR}')
  end

  def test_render_env_with_shell_command
    result = @subject.render_env('$(echo hello)')
    assert_equal 'hello', result
  end

  def test_render_erb_with_instance_variable
    @subject.instance_variable_set('@test_var', 'hello')
    result = @subject.render_erb('Value is <%= @test_var %>')
    assert_equal 'Value is hello', result
  end
end
