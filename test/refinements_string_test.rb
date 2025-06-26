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
end