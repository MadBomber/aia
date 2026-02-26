# frozen_string_literal: true
# test/aia/decisions_test.rb

require_relative '../test_helper'

class DecisionsTest < Minitest::Test
  def setup
    @decisions = AIA::Decisions.new
  end

  def teardown
    super
  end

  # =========================================================================
  # Initialization
  # =========================================================================

  def test_initialization_creates_empty_classifications
    assert_equal [], @decisions.classifications
  end

  def test_initialization_creates_empty_model_decisions
    assert_equal [], @decisions.model_decisions
  end

  def test_initialization_creates_empty_mcp_activations
    assert_equal [], @decisions.mcp_activations
  end

  def test_initialization_creates_empty_tool_activations
    assert_equal [], @decisions.tool_activations
  end

  def test_initialization_creates_empty_gate_actions
    assert_equal [], @decisions.gate_actions
  end

  def test_initialization_creates_empty_learnings
    assert_equal [], @decisions.learnings
  end

  # =========================================================================
  # add
  # =========================================================================

  def test_add_classification_appends_to_classifications
    @decisions.add(:classification, domain: "code", language: "ruby")

    assert_equal 1, @decisions.classifications.size
    assert_equal({ domain: "code", language: "ruby" }, @decisions.classifications.first)
  end

  def test_add_model_decision_appends_to_model_decisions
    @decisions.add(:model_decision, model: "claude-sonnet-4-20250514", reason: "best for code")

    assert_equal 1, @decisions.model_decisions.size
    assert_equal "claude-sonnet-4-20250514", @decisions.model_decisions.first[:model]
    assert_equal "best for code", @decisions.model_decisions.first[:reason]
  end

  def test_add_mcp_activate_appends_to_mcp_activations
    @decisions.add(:mcp_activate, server: "github", reason: "repo context detected")

    assert_equal 1, @decisions.mcp_activations.size
    assert_equal "github", @decisions.mcp_activations.first[:server]
  end

  def test_add_tool_activate_appends_to_tool_activations
    @decisions.add(:tool_activate, tool: "word_count", reason: "text domain")

    assert_equal 1, @decisions.tool_activations.size
    assert_equal "word_count", @decisions.tool_activations.first[:tool]
  end

  def test_add_gate_appends_to_gate_actions
    @decisions.add(:gate, action: "block", reason: "sensitive content")

    assert_equal 1, @decisions.gate_actions.size
    assert_equal "block", @decisions.gate_actions.first[:action]
    assert_equal "sensitive content", @decisions.gate_actions.first[:reason]
  end

  def test_add_learning_appends_to_learnings
    @decisions.add(:learning, insight: "user prefers verbose output")

    assert_equal 1, @decisions.learnings.size
    assert_equal "user prefers verbose output", @decisions.learnings.first[:insight]
  end

  def test_add_multiple_items_to_same_type
    @decisions.add(:classification, domain: "code")
    @decisions.add(:classification, domain: "prose")
    @decisions.add(:classification, domain: "math")

    assert_equal 3, @decisions.classifications.size
    assert_equal "code",  @decisions.classifications[0][:domain]
    assert_equal "prose", @decisions.classifications[1][:domain]
    assert_equal "math",  @decisions.classifications[2][:domain]
  end

  def test_add_with_unknown_type_does_nothing
    @decisions.add(:unknown_type, data: "something")

    assert_equal [], @decisions.classifications
    assert_equal [], @decisions.model_decisions
    assert_equal [], @decisions.mcp_activations
    assert_equal [], @decisions.gate_actions
    assert_equal [], @decisions.learnings
  end

  def test_add_with_empty_attrs
    @decisions.add(:classification)

    assert_equal 1, @decisions.classifications.size
    assert_equal({}, @decisions.classifications.first)
  end

  # =========================================================================
  # has_any?
  # =========================================================================

  def test_has_any_returns_false_when_empty
    refute @decisions.has_any?(:classification)
    refute @decisions.has_any?(:model_decision)
    refute @decisions.has_any?(:mcp_activate)
    refute @decisions.has_any?(:tool_activate)
    refute @decisions.has_any?(:gate)
    refute @decisions.has_any?(:learning)
  end

  def test_has_any_returns_true_after_add_classification
    @decisions.add(:classification, domain: "code")
    assert @decisions.has_any?(:classification)
  end

  def test_has_any_returns_true_after_add_model_decision
    @decisions.add(:model_decision, model: "gpt-4o")
    assert @decisions.has_any?(:model_decision)
  end

  def test_has_any_returns_true_after_add_mcp_activate
    @decisions.add(:mcp_activate, server: "github")
    assert @decisions.has_any?(:mcp_activate)
  end

  def test_has_any_returns_true_after_add_tool_activate
    @decisions.add(:tool_activate, tool: "word_count")
    assert @decisions.has_any?(:tool_activate)
  end

  def test_has_any_returns_true_after_add_gate
    @decisions.add(:gate, action: "allow")
    assert @decisions.has_any?(:gate)
  end

  def test_has_any_returns_true_after_add_learning
    @decisions.add(:learning, insight: "something")
    assert @decisions.has_any?(:learning)
  end

  def test_has_any_returns_false_for_unknown_type
    @decisions.add(:classification, domain: "code")
    refute @decisions.has_any?(:nonexistent)
  end

  # =========================================================================
  # clear!
  # =========================================================================

  def test_clear_empties_all_collections
    @decisions.add(:classification, domain: "code")
    @decisions.add(:model_decision, model: "gpt-4o")
    @decisions.add(:mcp_activate, server: "github")
    @decisions.add(:tool_activate, tool: "word_count")
    @decisions.add(:gate, action: "allow")
    @decisions.add(:learning, insight: "something")

    @decisions.clear!

    assert_empty @decisions.classifications
    assert_empty @decisions.model_decisions
    assert_empty @decisions.mcp_activations
    assert_empty @decisions.tool_activations
    assert_empty @decisions.gate_actions
    assert_empty @decisions.learnings
  end

  def test_clear_on_already_empty_does_not_raise
    @decisions.clear!

    assert_empty @decisions.classifications
    assert_empty @decisions.model_decisions
  end

  def test_add_works_after_clear
    @decisions.add(:classification, domain: "code")
    @decisions.clear!
    @decisions.add(:classification, domain: "prose")

    assert_equal 1, @decisions.classifications.size
    assert_equal "prose", @decisions.classifications.first[:domain]
  end

  # =========================================================================
  # to_h
  # =========================================================================

  def test_to_h_returns_all_collections_as_hash
    hash = @decisions.to_h

    assert_instance_of Hash, hash
    assert_equal 6, hash.keys.size
    assert hash.key?(:classifications)
    assert hash.key?(:model_decisions)
    assert hash.key?(:mcp_activations)
    assert hash.key?(:tool_activations)
    assert hash.key?(:gate_actions)
    assert hash.key?(:learnings)
  end

  def test_to_h_returns_empty_arrays_when_no_data
    hash = @decisions.to_h

    assert_equal [], hash[:classifications]
    assert_equal [], hash[:model_decisions]
    assert_equal [], hash[:mcp_activations]
    assert_equal [], hash[:tool_activations]
    assert_equal [], hash[:gate_actions]
    assert_equal [], hash[:learnings]
  end

  def test_to_h_includes_added_data
    @decisions.add(:classification, domain: "code")
    @decisions.add(:model_decision, model: "gpt-4o")

    hash = @decisions.to_h

    assert_equal 1, hash[:classifications].size
    assert_equal "code", hash[:classifications].first[:domain]
    assert_equal 1, hash[:model_decisions].size
    assert_equal "gpt-4o", hash[:model_decisions].first[:model]
  end

  # =========================================================================
  # recommended_model
  # =========================================================================

  def test_recommended_model_returns_first_model_name
    @decisions.add(:model_decision, model: "claude-sonnet-4-20250514", reason: "best")
    @decisions.add(:model_decision, model: "gpt-4o", reason: "fallback")

    assert_equal "claude-sonnet-4-20250514", @decisions.recommended_model
  end

  def test_recommended_model_returns_nil_when_empty
    assert_nil @decisions.recommended_model
  end

  # =========================================================================
  # activated_mcp_servers
  # =========================================================================

  def test_activated_mcp_servers_returns_names
    @decisions.add(:mcp_activate, server: "github", reason: "code domain")
    @decisions.add(:mcp_activate, server: "filesystem", reason: "code domain")

    assert_equal %w[github filesystem], @decisions.activated_mcp_servers
  end

  def test_activated_mcp_servers_returns_empty_when_none
    assert_equal [], @decisions.activated_mcp_servers
  end

  # =========================================================================
  # activated_tools
  # =========================================================================

  def test_activated_tools_returns_names
    @decisions.add(:tool_activate, tool: "word_count", reason: "text domain")
    @decisions.add(:tool_activate, tool: "search_files", reason: "code domain")

    assert_equal %w[word_count search_files], @decisions.activated_tools
  end

  def test_activated_tools_returns_empty_when_none
    assert_equal [], @decisions.activated_tools
  end

  # =========================================================================
  # gate_warnings / gate_blocks
  # =========================================================================

  def test_gate_warnings_excludes_blocks
    @decisions.add(:gate, action: "warn", message: "warning 1")
    @decisions.add(:gate, action: "block", message: "blocked")
    @decisions.add(:gate, action: "warn", message: "warning 2")

    warnings = @decisions.gate_warnings
    assert_equal 2, warnings.size
    assert warnings.all? { |w| w[:action] == "warn" }
  end

  def test_gate_blocks_excludes_warnings
    @decisions.add(:gate, action: "warn", message: "warning")
    @decisions.add(:gate, action: "block", message: "blocked 1")
    @decisions.add(:gate, action: "block", message: "blocked 2")

    blocks = @decisions.gate_blocks
    assert_equal 2, blocks.size
    assert blocks.all? { |b| b[:action] == "block" }
  end

  def test_gate_warnings_returns_empty_when_none
    assert_equal [], @decisions.gate_warnings
  end

  def test_gate_blocks_returns_empty_when_none
    assert_equal [], @decisions.gate_blocks
  end

  # =========================================================================
  # to_h (continued)
  # =========================================================================

  def test_to_h_returns_duplicated_arrays
    @decisions.add(:classification, domain: "code")

    hash = @decisions.to_h
    hash[:classifications] << { domain: "injected" }

    assert_equal 1, @decisions.classifications.size,
      "Modifying to_h output should not affect internal state"
  end
end
