# frozen_string_literal: true

# test/aia/config/value_caster_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia/config/value_caster'

class ValueCasterTest < Minitest::Test
  Caster = AIA::ValueCaster

  def test_boolean_words
    assert_equal true,  Caster.cast('true', false)
    assert_equal true,  Caster.cast(' YES ', false)
    assert_equal false, Caster.cast('false', true)
    assert_equal false, Caster.cast('0', true)
  end

  def test_unrecognized_boolean_word_is_kept
    assert_equal 'maybe', Caster.cast('maybe', true)
  end

  def test_integer_and_float
    assert_equal 500, Caster.cast('500', 32_767)
    assert_in_delta 0.2, Caster.cast('0.2', 0.7)
    assert_in_delta 1.0, Caster.cast('1', 0.7)
  end

  def test_unparsable_number_is_kept
    assert_equal 'lots', Caster.cast('lots', 32_767)
    assert_equal '08x', Caster.cast('08x', 1)
  end

  def test_list_is_split_on_commas
    assert_equal %w[a.rb b.rb], Caster.cast('a.rb, b.rb', [])
    assert_equal [], Caster.cast(' , ', [])
  end

  def test_strings_and_non_strings_pass_through
    assert_equal 'say', Caster.cast('say', 'afplay')
    assert_equal 3, Caster.cast(3, 1)
    assert_equal %w[x], Caster.cast(%w[x], [])
  end

  def test_untyped_defaults_supply_a_type
    assert_in_delta 0.8, Caster.cast('0.8', Caster.default_for('llm.top_p', nil))
    assert_equal %w[a b], Caster.cast('a,b', Caster.default_for('tools.allowed', nil))
    assert_nil Caster.default_for('prompts.role', nil)
  end

  def test_cast_section_converts_in_place_and_recurses
    section = { temperature: '0.2', nested: { flag: 'false' }, name: 'x' }
    defaults = { temperature: 0.7, nested: { flag: true }, name: 'y' }
    Caster.cast_section!(section, defaults, 'llm')
    assert_in_delta 0.2, section[:temperature]
    assert_equal false, section[:nested][:flag]
    assert_equal 'x', section[:name]
  end

  def test_cast_section_ignores_nil_section
    assert_nil Caster.cast_section!(nil, { a: 1 }, 'x')
  end
end
