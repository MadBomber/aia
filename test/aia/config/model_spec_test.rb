require_relative '../../test_helper'

class ModelSpecTest < Minitest::Test
  def test_initialize_with_symbol_keys
    spec = AIA::ModelSpec.new(name: 'gpt-4o', role: 'architect')
    assert_equal 'gpt-4o', spec.name
    assert_equal 'architect', spec.role
    assert_equal 1, spec.instance
    assert_equal 'gpt-4o', spec.internal_id
  end

  def test_initialize_with_string_keys
    spec = AIA::ModelSpec.new('name' => 'claude-3', 'role' => 'reviewer')
    assert_equal 'claude-3', spec.name
    assert_equal 'reviewer', spec.role
  end

  def test_initialize_defaults
    spec = AIA::ModelSpec.new
    assert_nil spec.name
    assert_nil spec.role
    assert_equal 1, spec.instance
    assert_nil spec.internal_id
  end

  def test_initialize_with_custom_instance_and_internal_id
    spec = AIA::ModelSpec.new(name: 'gpt-4o', instance: 3, internal_id: 'gpt-4o#3')
    assert_equal 3, spec.instance
    assert_equal 'gpt-4o#3', spec.internal_id
  end

  def test_to_h
    spec = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 2, internal_id: 'gpt-4o#2')
    h = spec.to_h
    assert_equal({ name: 'gpt-4o', role: 'coder', instance: 2, internal_id: 'gpt-4o#2' }, h)
  end

  def test_to_s_with_role
    spec = AIA::ModelSpec.new(name: 'gpt-4o', role: 'architect')
    assert_equal 'gpt-4o=architect', spec.to_s
  end

  def test_to_s_without_role
    spec = AIA::ModelSpec.new(name: 'gpt-4o')
    assert_equal 'gpt-4o', spec.to_s
  end

  def test_to_s_with_nil_name
    spec = AIA::ModelSpec.new
    assert_equal '', spec.to_s
  end

  def test_equality
    a = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    b = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    assert_equal a, b
  end

  def test_inequality_different_name
    a = AIA::ModelSpec.new(name: 'gpt-4o')
    b = AIA::ModelSpec.new(name: 'claude-3')
    refute_equal a, b
  end

  def test_inequality_different_role
    a = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder')
    b = AIA::ModelSpec.new(name: 'gpt-4o', role: 'reviewer')
    refute_equal a, b
  end

  def test_inequality_different_instance
    a = AIA::ModelSpec.new(name: 'gpt-4o', instance: 1)
    b = AIA::ModelSpec.new(name: 'gpt-4o', instance: 2)
    refute_equal a, b
  end

  def test_inequality_with_non_model_spec
    spec = AIA::ModelSpec.new(name: 'gpt-4o')
    refute_equal spec, "gpt-4o"
    refute_equal spec, nil
    refute_equal spec, 42
  end

  def test_eql
    a = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    b = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    assert a.eql?(b)
  end

  def test_hash_equality
    a = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    b = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    assert_equal a.hash, b.hash
  end

  def test_hash_as_hash_key
    a = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    b = AIA::ModelSpec.new(name: 'gpt-4o', role: 'coder', instance: 1)
    h = { a => 'value' }
    assert_equal 'value', h[b]
  end

  def test_role_predicate_with_role
    spec = AIA::ModelSpec.new(name: 'gpt-4o', role: 'architect')
    assert spec.role?
  end

  def test_role_predicate_without_role
    spec = AIA::ModelSpec.new(name: 'gpt-4o')
    refute spec.role?
  end

  def test_role_predicate_with_empty_role
    spec = AIA::ModelSpec.new(name: 'gpt-4o', role: '')
    refute spec.role?
  end

  def test_duplicate_predicate_true
    spec = AIA::ModelSpec.new(name: 'gpt-4o', instance: 2)
    assert spec.duplicate?
  end

  def test_duplicate_predicate_false
    spec = AIA::ModelSpec.new(name: 'gpt-4o', instance: 1)
    refute spec.duplicate?
  end

  def test_accessors_are_mutable
    spec = AIA::ModelSpec.new(name: 'gpt-4o')
    spec.name = 'claude-3'
    spec.role = 'reviewer'
    spec.instance = 5
    spec.internal_id = 'claude-3#5'

    assert_equal 'claude-3', spec.name
    assert_equal 'reviewer', spec.role
    assert_equal 5, spec.instance
    assert_equal 'claude-3#5', spec.internal_id
  end
end
