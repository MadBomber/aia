require_relative 'test_helper'

require 'ostruct'
require 'extensions/openstruct_merge'

class OpenStructMergeTest < Minitest::Test
  def test_merge_hashes_and_openstructs
    os1 = OpenStruct.new(a: 1, b: 2)
    os2 = OpenStruct.new(b: 3, c: 4)
    hash = { d: 5, e: { x: 9 } }

    merged = OpenStruct.merge(os1, os2, hash)
    assert_equal 1, merged.a
    assert_equal 3, merged.b  # os2 overrides os1
    assert_equal 4, merged.c
    assert merged.respond_to?(:d)
    assert_equal 5, merged.d
    # Nested merge should produce OpenStruct for e
    assert_kind_of OpenStruct, merged.e
    assert_equal 9, merged.e.x
  end

  def test_merge_deep_nested
    os1 = OpenStruct.new(nested: OpenStruct.new(alpha: 1))
    hash = { nested: { beta: 2 } }

    merged = OpenStruct.merge(os1, hash)
    assert_kind_of OpenStruct, merged.nested
    assert_equal 1, merged.nested.alpha
    assert_equal 2, merged.nested.beta
  end

  def test_invalid_argument_raises
    assert_raises(ArgumentError) { OpenStruct.merge(42) }
  end
end