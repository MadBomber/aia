require_relative '../../test_helper'

class DirectivesExecutionTest < Minitest::Test
  def setup
    @instance = AIA::ExecutionDirectives.new
  end

  def test_ruby_evaluates_code
    result = @instance.ruby(['1 + 2'])
    assert_equal '3', result
  end

  def test_ruby_evaluates_string_expression
    result = @instance.ruby(['"hello".upcase'])
    assert_equal 'HELLO', result
  end

  def test_ruby_joins_multiple_args
    result = @instance.ruby(['[1,', '2,', '3].sum'])
    assert_equal '6', result
  end

  def test_ruby_handles_error
    result = @instance.ruby(['undefined_var_xyz'])
    assert_includes result, 'ruby code failed'
    assert_includes result, 'undefined_var_xyz'
  end

  def test_ruby_returns_string
    result = @instance.ruby(['42'])
    assert_instance_of String, result
  end

  def test_shell_executes_command
    result = @instance.shell(['echo', 'hello'])
    assert_equal "hello\n", result
  end

  def test_shell_joins_args
    result = @instance.shell(['echo', 'hello', 'world'])
    assert_equal "hello world\n", result
  end

  def test_rb_alias
    assert_equal @instance.method(:ruby).original_name,
                 @instance.method(:rb).original_name
  end

  def test_sh_alias
    assert_equal @instance.method(:shell).original_name,
                 @instance.method(:sh).original_name
  end
end
