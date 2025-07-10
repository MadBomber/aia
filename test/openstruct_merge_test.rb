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

  def test_merge_empty_args
    # Test merging with no arguments
    result = OpenStruct.merge()
    assert_kind_of OpenStruct, result
    # Should be empty since no args provided
  end

  def test_merge_single_openstruct
    os = OpenStruct.new(a: 1, b: 2)
    result = OpenStruct.merge(os)
    assert_equal 1, result.a
    assert_equal 2, result.b
  end

  def test_merge_single_hash
    hash = { a: 1, b: 2 }
    result = OpenStruct.merge(hash)
    assert_equal 1, result.a
    assert_equal 2, result.b
  end

  def test_merge_with_nil_values
    os1 = OpenStruct.new(a: 1, b: nil)
    os2 = OpenStruct.new(b: 2, c: nil)
    
    result = OpenStruct.merge(os1, os2)
    assert_equal 1, result.a
    assert_equal 2, result.b
    assert_nil result.c
  end

  def test_merge_overwrite_nested_structures
    os1 = OpenStruct.new(data: { x: 1, y: 2 })
    os2 = OpenStruct.new(data: { y: 3, z: 4 })
    
    result = OpenStruct.merge(os1, os2)
    assert_kind_of OpenStruct, result.data
    assert_equal 1, result.data.x
    assert_equal 3, result.data.y  # os2 overrides os1
    assert_equal 4, result.data.z
  end

  def test_merge_different_error_types
    # Test with string
    assert_raises(ArgumentError) { OpenStruct.merge("string") }
    # Test with array
    assert_raises(ArgumentError) { OpenStruct.merge([1, 2, 3]) }
    # Test with number
    assert_raises(ArgumentError) { OpenStruct.merge(3.14) }
  end

  def test_set_value_private_method_behavior
    # Test the set_value method indirectly through merge
    result = OpenStruct.new
    os = OpenStruct.new(simple: "value")
    nested_hash = { complex: { deep: "nested" } }
    
    merged = OpenStruct.merge(os, nested_hash)
    assert_equal "value", merged.simple
    assert_kind_of OpenStruct, merged.complex
    assert_equal "nested", merged.complex.deep
  end

  def test_merge_preserves_original_objects
    # Ensure original objects are not modified
    os1 = OpenStruct.new(a: 1)
    os2 = OpenStruct.new(b: 2)
    
    original_os1_vars = os1.instance_variables.dup
    original_os2_vars = os2.instance_variables.dup
    
    OpenStruct.merge(os1, os2)
    
    # Original objects should be unchanged
    assert_equal original_os1_vars, os1.instance_variables
    assert_equal original_os2_vars, os2.instance_variables
    assert_equal 1, os1.a
    assert_equal 2, os2.b
  end
end