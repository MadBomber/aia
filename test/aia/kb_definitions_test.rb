# frozen_string_literal: true
# test/aia/kb_definitions_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class KBDefinitionsTest < Minitest::Test
  def setup
    @config = create_test_config
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:user_rules).returns(Hash.new { |h, k| h[k] = [] })
    @decisions = AIA::Decisions.new
  end

  # =========================================================================
  # build_all_kbs
  # =========================================================================

  def test_build_all_kbs_returns_hash_with_five_keys
    result = AIA::KBDefinitions.build_all_kbs(@decisions)
    assert_instance_of Hash, result
    assert_equal 5, result.size
  end

  def test_build_all_kbs_keys_are_correct
    result = AIA::KBDefinitions.build_all_kbs(@decisions)
    assert_equal %i[classify model_select route gate learn].sort, result.keys.sort
  end

  # =========================================================================
  # Individual KB builders
  # =========================================================================

  def test_build_classification_kb_returns_knowledge_base
    kb = AIA::KBDefinitions.build_classification_kb(@decisions)
    refute_nil kb
    assert kb.respond_to?(:run), "KB must respond to :run"
    assert kb.respond_to?(:rules), "KB must respond to :rules"
  end

  def test_build_model_selection_kb_returns_knowledge_base
    kb = AIA::KBDefinitions.build_model_selection_kb(@decisions)
    refute_nil kb
    assert kb.respond_to?(:run), "KB must respond to :run"
  end

  def test_build_routing_kb_returns_knowledge_base
    kb = AIA::KBDefinitions.build_routing_kb(@decisions)
    refute_nil kb
    assert kb.respond_to?(:run), "KB must respond to :run"
  end

  def test_build_quality_gate_kb_returns_knowledge_base
    kb = AIA::KBDefinitions.build_quality_gate_kb(@decisions)
    refute_nil kb
    assert kb.respond_to?(:run), "KB must respond to :run"
  end

  def test_build_learning_kb_returns_knowledge_base
    kb = AIA::KBDefinitions.build_learning_kb(@decisions)
    refute_nil kb
    assert kb.respond_to?(:run), "KB must respond to :run"
  end

  # =========================================================================
  # Functional: classification KB fires rules
  # =========================================================================

  def test_classification_kb_fires_code_rule
    kb = AIA::KBDefinitions.build_classification_kb(@decisions)
    kb.assert(:turn_input, text: "refactor this method", length: 21)
    kb.run

    code_classifications = @decisions.classifications.select { |c| c[:domain] == "code" }
    refute_empty code_classifications, "Expected code domain classification"
    assert code_classifications.any? { |c| c[:source] == "code_request" }
  end

  def test_classification_kb_fires_image_rule
    kb = AIA::KBDefinitions.build_classification_kb(@decisions)
    kb.assert(:turn_input, text: "draw a diagram of the system", length: 29)
    kb.run

    image_classifications = @decisions.classifications.select { |c| c[:domain] == "image" }
    refute_empty image_classifications, "Expected image domain classification"
    assert image_classifications.any? { |c| c[:source] == "image_request" }
  end

  private

  def create_test_config
    OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      pipeline: [],
      context_files: [],
      mcp_servers: [],
      flags: OpenStruct.new(
        chat: false,
        debug: false,
        verbose: false,
        consensus: false,
        no_mcp: false
      ),
      rules: OpenStruct.new(
        dir: nil,
        enabled: false
      )
    )
  end
end
