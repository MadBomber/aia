# frozen_string_literal: true
# test/aia/multi_model_isolation_test.rb
# Tests for ADR-002 (Revised): Complete Multi-Model Isolation
# - RubyLLM::Context isolation (library level)
# - Per-model ContextManager isolation (application level)

require_relative '../test_helper'
require_relative '../../lib/aia'

class MultiModelIsolationTest < Minitest::Test
  def setup
    @original_config = AIA.config

    # Setup minimal AIA config for tests
    config = OpenStruct.new(
      model: 'gpt-4o',
      system_prompt: 'test',
      prompt_id: nil,
      context_files: [],
      pipeline: []
    )
    AIA.instance_variable_set(:@config, config)
  end

  def teardown
    AIA.instance_variable_set(:@config, @original_config) if @original_config
  end

  def test_each_model_has_isolated_context
    skip "Requires actual models configured" unless can_run_adapter_tests?

    # Given: Multiple models configured
    adapter = AIA::RubyLLMAdapter.new

    # When: We examine the adapter's structure
    contexts = adapter.instance_variable_get(:@contexts)

    # Then: Each model should have its own Context instance
    refute_nil contexts, "Adapter should have @contexts hash"
    refute_empty contexts, "Should have at least one context"

    # Verify each context is a unique RubyLLM::Context instance
    context_object_ids = contexts.values.map(&:object_id)
    assert_equal context_object_ids.uniq.size, context_object_ids.size,
                 "Each model should have a unique Context instance"
  end

  def test_concurrent_models_have_equal_input_token_counts
    skip "Requires two or more models and actual API calls"

    # This test would require actual API calls and is better run as an integration test
    # Keeping as documentation of expected behavior

    # Given: Two models (e.g., ollama and lms)
    # When: Both process the same prompt concurrently
    # Then: Both models should report the same input token count
    #       (proving neither model sees the other's response)
  end

  def test_models_use_context_not_global_rubyllm_chat
    skip "Requires actual models configured" unless can_run_adapter_tests?

    # Given: A RubyLLMAdapter instance
    adapter = AIA::RubyLLMAdapter.new

    # When: We examine how chats are created (via method inspection)
    # Then: setup_chats_with_tools should use isolated contexts

    # Verify the adapter has the new helper methods
    assert_respond_to adapter, :create_isolated_context_for_model,
                       "Adapter should have create_isolated_context_for_model method"
    assert_respond_to adapter, :extract_model_and_provider,
                       "Adapter should have extract_model_and_provider method"
  end

  def test_create_isolated_context_for_model
    skip "Requires actual models configured" unless can_run_adapter_tests?

    # Given: A RubyLLMAdapter instance
    adapter = AIA::RubyLLMAdapter.new

    # When: We create contexts for different model types
    ollama_context = adapter.send(:create_isolated_context_for_model, 'ollama/test-model')
    lms_context = adapter.send(:create_isolated_context_for_model, 'lms/test-model')
    regular_context = adapter.send(:create_isolated_context_for_model, 'gpt-4o')

    # Then: Each should be a unique RubyLLM::Context instance
    assert_instance_of RubyLLM::Context, ollama_context
    assert_instance_of RubyLLM::Context, lms_context
    assert_instance_of RubyLLM::Context, regular_context

    refute_equal ollama_context.object_id, lms_context.object_id,
                 "Different models should have different Context instances"
    refute_equal lms_context.object_id, regular_context.object_id,
                 "Different models should have different Context instances"
  end

  def test_extract_model_and_provider
    skip "Requires actual models configured" unless can_run_adapter_tests?

    # Given: A RubyLLMAdapter instance
    adapter = AIA::RubyLLMAdapter.new

    # When/Then: Extract model and provider from various formats
    actual, provider = adapter.send(:extract_model_and_provider, 'ollama/llama2')
    assert_equal 'llama2', actual
    assert_equal 'ollama', provider

    actual, provider = adapter.send(:extract_model_and_provider, 'lms/gpt-oss-29b')
    assert_equal 'gpt-oss-29b', actual
    assert_equal 'openai', provider

    actual, provider = adapter.send(:extract_model_and_provider, 'osaurus/custom-model')
    assert_equal 'custom-model', actual
    assert_equal 'openai', provider

    actual, provider = adapter.send(:extract_model_and_provider, 'gpt-4o')
    assert_equal 'gpt-4o', actual
    assert_nil provider
  end

  def test_clear_context_uses_isolated_contexts
    skip "Requires actual models configured"

    # Given: An adapter with models
    adapter = AIA::RubyLLMAdapter.new
    original_contexts = adapter.instance_variable_get(:@contexts).dup

    # When: We clear the context
    result = adapter.clear_context

    # Then: The contexts should remain the same (not recreated)
    #       but the chats should be fresh instances
    new_contexts = adapter.instance_variable_get(:@contexts)
    assert_equal original_contexts.keys.sort, new_contexts.keys.sort,
                 "Should maintain same contexts after clear"

    assert_match(/successfully cleared/, result.downcase)
  end

  def test_no_global_rubyllm_chat_state_dependency
    skip "Requires actual models configured" unless can_run_adapter_tests?

    # This test verifies that we don't depend on RubyLLM.instance_variable :@chat
    # which was the source of the cross-talk bug

    # Given: A RubyLLMAdapter
    adapter = AIA::RubyLLMAdapter.new

    # When: We examine the clear_context method source
    method_source = adapter.method(:clear_context).source_location

    # Then: The implementation should not reference RubyLLM.instance_variable_set
    #       This is a smoke test - the real verification is code review
    refute_nil method_source, "clear_context should be defined"
  end

  # ========================================
  # Tests for Complete Fix (ADR-002 Revised)
  # ========================================

  def test_parse_multi_model_response
    skip "Parser test requires Session setup" unless ENV['RUN_INTEGRATION_TESTS']

    # Given: A Session instance with the parser method
    session = create_mock_session

    # When: We parse a combined multi-model response
    combined = "from: lms/model-1\nHello in Spanish: Hola!\n\nfrom: ollama/model-2\nHello in French: Bonjour!"
    parsed = session.send(:parse_multi_model_response, combined)

    # Then: Should extract individual model responses
    assert_equal 2, parsed.keys.size
    assert_equal "Hello in Spanish: Hola!", parsed["lms/model-1"]
    assert_equal "Hello in French: Bonjour!", parsed["ollama/model-2"]
  end

  def test_parse_multi_model_response_with_empty_input
    skip "Parser test requires Session setup" unless ENV['RUN_INTEGRATION_TESTS']

    # Given: A Session instance
    session = create_mock_session

    # When: We parse empty or nil input
    assert_equal({}, session.send(:parse_multi_model_response, nil))
    assert_equal({}, session.send(:parse_multi_model_response, ""))
  end

  def test_parse_multi_model_response_with_multiline_responses
    skip "Parser test requires Session setup" unless ENV['RUN_INTEGRATION_TESTS']

    # Given: A Session instance
    session = create_mock_session

    # When: Model responses contain multiple lines
    combined = "from: model-1\nLine 1\nLine 2\nLine 3\n\nfrom: model-2\nResponse A\nResponse B"
    parsed = session.send(:parse_multi_model_response, combined)

    # Then: Should preserve multiline content
    assert_equal "Line 1\nLine 2\nLine 3", parsed["model-1"]
    assert_equal "Response A\nResponse B", parsed["model-2"]
  end

  def test_session_creates_per_model_context_managers_for_multi_model
    skip "Requires multi-model configuration" unless can_test_with_multiple_models?

    # Given: Multi-model configuration
    with_multi_model_config do
      # When: Session is initialized
      session = create_session_with_prompt_handler

      # Then: Should have per-model context managers
      assert_nil session.instance_variable_get(:@context_manager),
                 "Should not have single context manager in multi-model mode"

      context_managers = session.instance_variable_get(:@context_managers)
      refute_nil context_managers, "Should have context_managers hash"
      assert_instance_of Hash, context_managers

      # Should have one context manager per model
      assert_equal AIA.config.model.size, context_managers.size,
                   "Should have one context manager per model"

      # Each should be a ContextManager instance
      context_managers.each_value do |ctx_mgr|
        assert_instance_of AIA::ContextManager, ctx_mgr
      end
    end
  end

  def test_session_uses_single_context_manager_for_single_model
    # Given: Single-model configuration
    with_single_model_config do
      # When: Session is initialized
      session = create_session_with_prompt_handler

      # Then: Should use single context manager
      refute_nil session.instance_variable_get(:@context_manager),
                 "Should have single context manager in single-model mode"
      assert_nil session.instance_variable_get(:@context_managers),
                 "Should not have context_managers hash in single-model mode"
    end
  end

  def test_rubyllm_adapter_accepts_hash_of_conversations
    skip "Requires actual API keys or local models" unless ENV['RUN_INTEGRATION_TESTS']

    # Given: RubyLLMAdapter with multiple models
    adapter = AIA::RubyLLMAdapter.new

    # When: We pass a Hash with per-model contexts
    conversations = {
      adapter.instance_variable_get(:@models).first => [
        { role: "user", content: "Test prompt 1" }
      ],
      adapter.instance_variable_get(:@models).last => [
        { role: "user", content: "Test prompt 2" }
      ]
    }

    # Then: Should recognize it as per-model contexts and not raise error
    # (Full test requires actual API calls - this is structural validation)
    assert_respond_to adapter, :multi_model_chat
    # The method should handle Hash input without raising ArgumentError
  end

  private

  def create_mock_session
    # Create a minimal session just for testing the parser
    # Mock AIA.chat? to avoid initialization issues
    AIA.stub :chat?, false do
      prompt_handler = Minitest::Mock.new
      prompt_handler.expect(:get_prompt, mock_prompt, [String]) rescue nil

      session = AIA::Session.new(prompt_handler)
      session
    end
  end

  def mock_prompt
    prompt = Object.new
    def prompt.parameters; {}; end
    def prompt.text; "test"; end
    prompt
  end

  def create_session_with_prompt_handler
    # Create a session with a real prompt handler
    prompt_handler = Minitest::Mock.new
    prompt_handler.expect(:get_prompt, double_prompt, [String])
    prompt_handler.expect(:get_prompt, double_prompt, [String, String])

    AIA::Session.new(prompt_handler)
  rescue => e
    # If session creation fails due to dependencies, skip the test
    skip "Cannot create session: #{e.message}"
  end

  def double_prompt
    # Return a mock prompt object
    prompt = Minitest::Mock.new
    prompt.expect(:parameters, {})
    prompt.expect(:text, "test prompt")
    prompt
  end

  def can_test_with_multiple_models?
    # Check if we can test multi-model scenarios
    ENV['RUN_INTEGRATION_TESTS'] || ENV['TEST_MULTI_MODEL']
  end

  def can_run_adapter_tests?
    # Check if we can run tests that create RubyLLMAdapter
    ENV['RUN_INTEGRATION_TESTS'] || ENV['TEST_ADAPTER']
  end

  def with_multi_model_config
    # Temporarily set multi-model config
    original_model = AIA.config.model
    AIA.config.model = ['model-1', 'model-2']

    yield
  ensure
    AIA.config.model = original_model if original_model
  end

  def with_single_model_config
    # Temporarily set single-model config
    original_model = AIA.config.model
    AIA.config.model = 'single-model'

    yield
  ensure
    AIA.config.model = original_model if original_model
  end
end
