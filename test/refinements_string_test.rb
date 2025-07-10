require_relative 'test_helper'

# Test the Refinements::String module (include_all?/all? and include_any?/any?)
require 'refinements/string'

using Refinements

class RefinementsStringTest < Minitest::Test
  def test_include_all_with_single_substring
    str = 'hello world'
    assert str.include_all?('hello')
    assert str.all?('world')
  end

  def test_include_all_with_multiple_substrings
    str = 'quick brown fox'
    assert str.include_all?(['quick', 'fox'])
    refute str.include_all?(['quick', 'dog'])
  end

  def test_include_any_with_single_substring
    str = 'ruby testing'
    assert str.include_any?('test')
    assert str.any?('ruby')
  end

  def test_include_any_with_multiple_substrings
    str = 'minitest and mocha'
    assert str.include_any?(['rspec', 'mocha'])
    refute str.include_any?(['rspec', 'cucumber'])
  end

  def test_empty_substrings
    str = 'anything'
    assert str.include_all?([])
    refute str.include_any?([])
  end

  def test_empty_string_with_substrings
    str = ''
    refute str.include_all?('hello')
    refute str.include_any?('hello') 
    refute str.include_all?(['hello', 'world'])
    refute str.include_any?(['hello', 'world'])
  end

  def test_nil_and_edge_cases
    str = 'test string'
    # Test with nil (should be converted to array)
    assert str.include_all?(nil)  # Array(nil) = []
    refute str.include_any?(nil)  # Array(nil) = []
  end

  def test_alias_methods
    str = 'testing aliases'
    # Ensure aliases work exactly the same as main methods
    assert_equal str.include_all?('test'), str.all?('test')
    assert_equal str.include_any?('test'), str.any?('test')
    assert_equal str.include_all?(['test', 'alias']), str.all?(['test', 'alias'])
    assert_equal str.include_any?(['test', 'missing']), str.any?(['test', 'missing'])
  end

  def test_case_sensitivity
    str = 'Hello World'
    assert str.include_all?('Hello')
    refute str.include_all?('hello')  # case sensitive
    assert str.include_any?(['hello', 'World'])  # one matches
  end
end