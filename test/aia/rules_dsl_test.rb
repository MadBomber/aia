# frozen_string_literal: true
# test/aia/rules_dsl_test.rb

require_relative '../test_helper'

class RulesDslTest < Minitest::Test
  def setup
    AIA.clear_user_rules!
  end

  def teardown
    AIA.clear_user_rules!
    super
  end

  # =========================================================================
  # rules_for
  # =========================================================================

  def test_rules_for_stores_block_by_kb_name
    block = proc { "classify rule" }
    AIA.rules_for(:classify, &block)

    assert_equal 1, AIA.user_rules[:classify].size
    assert_equal block, AIA.user_rules[:classify].first
  end

  def test_rules_for_with_model_select_kb
    block = proc { "model select rule" }
    AIA.rules_for(:model_select, &block)

    assert_equal 1, AIA.user_rules[:model_select].size
    assert_equal block, AIA.user_rules[:model_select].first
  end

  def test_rules_for_with_route_kb
    block = proc { "route rule" }
    AIA.rules_for(:route, &block)

    assert_equal 1, AIA.user_rules[:route].size
  end

  def test_rules_for_with_gate_kb
    block = proc { "gate rule" }
    AIA.rules_for(:gate, &block)

    assert_equal 1, AIA.user_rules[:gate].size
  end

  def test_rules_for_with_learn_kb
    block = proc { "learn rule" }
    AIA.rules_for(:learn, &block)

    assert_equal 1, AIA.user_rules[:learn].size
  end

  # =========================================================================
  # Multiple rules_for calls
  # =========================================================================

  def test_multiple_rules_for_same_kb_accumulate
    block1 = proc { "first classify rule" }
    block2 = proc { "second classify rule" }
    block3 = proc { "third classify rule" }

    AIA.rules_for(:classify, &block1)
    AIA.rules_for(:classify, &block2)
    AIA.rules_for(:classify, &block3)

    assert_equal 3, AIA.user_rules[:classify].size
    assert_equal block1, AIA.user_rules[:classify][0]
    assert_equal block2, AIA.user_rules[:classify][1]
    assert_equal block3, AIA.user_rules[:classify][2]
  end

  def test_rules_for_different_kbs_stored_separately
    classify_block = proc { "classify" }
    model_block    = proc { "model" }
    gate_block     = proc { "gate" }

    AIA.rules_for(:classify, &classify_block)
    AIA.rules_for(:model_select, &model_block)
    AIA.rules_for(:gate, &gate_block)

    assert_equal 1, AIA.user_rules[:classify].size
    assert_equal 1, AIA.user_rules[:model_select].size
    assert_equal 1, AIA.user_rules[:gate].size

    assert_equal classify_block, AIA.user_rules[:classify].first
    assert_equal model_block, AIA.user_rules[:model_select].first
    assert_equal gate_block, AIA.user_rules[:gate].first
  end

  # =========================================================================
  # user_rules
  # =========================================================================

  def test_user_rules_returns_hash
    assert_kind_of Hash, AIA.user_rules
  end

  def test_user_rules_is_empty_after_clear
    assert_empty AIA.user_rules
  end

  def test_user_rules_returns_accumulated_rules
    AIA.rules_for(:classify) { "a" }
    AIA.rules_for(:model_select) { "b" }

    rules = AIA.user_rules

    assert rules.key?(:classify)
    assert rules.key?(:model_select)
    assert_equal 1, rules[:classify].size
    assert_equal 1, rules[:model_select].size
  end

  def test_user_rules_default_for_missing_kb_is_empty_array
    AIA.rules_for(:classify) { "a" }

    # Accessing a KB that has not been registered returns []
    # because of Hash.new { |h, k| h[k] = [] }
    assert_equal [], AIA.user_rules[:nonexistent_kb]
  end

  # =========================================================================
  # clear_user_rules!
  # =========================================================================

  def test_clear_user_rules_empties_everything
    AIA.rules_for(:classify) { "a" }
    AIA.rules_for(:model_select) { "b" }
    AIA.rules_for(:gate) { "c" }

    AIA.clear_user_rules!

    assert_empty AIA.user_rules
  end

  def test_clear_user_rules_on_already_empty_does_not_raise
    AIA.clear_user_rules!
    assert_empty AIA.user_rules
  end

  def test_rules_can_be_added_after_clear
    AIA.rules_for(:classify) { "before clear" }
    AIA.clear_user_rules!
    AIA.rules_for(:classify) { "after clear" }

    assert_equal 1, AIA.user_rules[:classify].size
  end

  # =========================================================================
  # Block invocation
  # =========================================================================

  def test_stored_blocks_are_callable
    called = false
    AIA.rules_for(:classify) { called = true }

    AIA.user_rules[:classify].first.call
    assert called, "The stored block should be callable"
  end

  def test_stored_blocks_preserve_return_values
    AIA.rules_for(:model_select) { "claude-sonnet-4-20250514" }

    result = AIA.user_rules[:model_select].first.call
    assert_equal "claude-sonnet-4-20250514", result
  end
end
