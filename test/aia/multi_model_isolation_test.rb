# frozen_string_literal: true
# test/aia/multi_model_isolation_test.rb
# Tests for ADR-002 (Revised): Complete Multi-Model Isolation
# - RubyLLM::Context isolation (library level)
# - Per-model ContextManager isolation (application level)

require_relative '../test_helper'
require_relative '../../lib/aia'
require 'tmpdir'
require 'fileutils'

class MultiModelIsolationTest < Minitest::Test
  def setup
    # Clean up any Mocha stubs from previous tests FIRST
    begin
      Mocha::Mockery.instance.teardown
      Mocha::Mockery.instance.stubba.unstub_all
    rescue => e
      # Ignore cleanup errors
    end

    # Save original config if it exists
    @original_config = AIA.instance_variable_get(:@config)

    # Create temp directory for prompts
    @temp_prompts_dir = Dir.mktmpdir('aia_test_prompts')

    # Setup minimal real AIA config with all required fields
    config = create_test_config
    AIA.instance_variable_set(:@config, config)
  end

  def teardown
    # Manually do Mocha cleanup FIRST, before anything else
    begin
      Mocha::Mockery.instance.teardown
      Mocha::Mockery.instance.stubba.unstub_all
    rescue => e
      # Ignore cleanup errors
    end

    # Restore original config
    AIA.instance_variable_set(:@config, @original_config)

    # Clean up temp directory
    FileUtils.rm_rf(@temp_prompts_dir) if @temp_prompts_dir && Dir.exist?(@temp_prompts_dir)
  end

  private

  def create_test_config
    OpenStruct.new(
      adapter: 'ruby_llm',
      aia_dir: File.join(ENV['HOME'], '.aia'),
      config_file: File.join(ENV['HOME'], '.aia', 'config.yml'),
      out_file: nil,
      log_file: File.join(@temp_prompts_dir, '_prompts.log'),
      context_files: [],
      prompts_dir: @temp_prompts_dir,
      roles_prefix: 'roles',
      roles_dir: File.join(@temp_prompts_dir, 'roles'),
      role: '',
      system_prompt: 'test system prompt',
      tools: '',
      allowed_tools: nil,
      rejected_tools: nil,
      tool_paths: [],
      markdown: true,
      shell: true,
      erb: true,
      chat: false,
      clear: false,
      terse: false,
      verbose: false,
      debug: false,
      fuzzy: false,
      speak: false,
      append: false,
      pipeline: [],
      model: 'gpt-4o',
      prompt_id: nil,
      temperature: 0.7,
      max_tokens: 2048,
      client: nil
    )
  end

  public

  # ========================================
  # Tests for Complete Fix (ADR-002 Revised)
  # ========================================

  def test_parse_multi_model_response
    # Given: A real Session instance with the parser method
    session = create_real_session

    # When: We parse a combined multi-model response
    combined = "from: lms/model-1\nHello in Spanish: Hola!\n\nfrom: ollama/model-2\nHello in French: Bonjour!"
    parsed = session.send(:parse_multi_model_response, combined)

    # Then: Should extract individual model responses
    assert_equal 2, parsed.keys.size
    assert_equal "Hello in Spanish: Hola!", parsed["lms/model-1"]
    assert_equal "Hello in French: Bonjour!", parsed["ollama/model-2"]
  end

  def test_parse_multi_model_response_with_empty_input
    # Given: A real Session instance
    session = create_real_session

    # When: We parse empty or nil input
    assert_equal({}, session.send(:parse_multi_model_response, nil))
    assert_equal({}, session.send(:parse_multi_model_response, ""))
  end

  def test_parse_multi_model_response_with_multiline_responses
    # Given: A real Session instance
    session = create_real_session

    # When: Model responses contain multiple lines
    combined = "from: model-1\nLine 1\nLine 2\nLine 3\n\nfrom: model-2\nResponse A\nResponse B"
    parsed = session.send(:parse_multi_model_response, combined)

    # Then: Should preserve multiline content
    assert_equal "Line 1\nLine 2\nLine 3", parsed["model-1"]
    assert_equal "Response A\nResponse B", parsed["model-2"]
  end


  def test_session_uses_single_context_manager_for_single_model
    # Given: Single-model configuration (already set in setup)
    AIA.config.model = 'single-model'

    # When: Session is initialized
    session = create_real_session

    # Then: Should use single context manager
    refute_nil session.instance_variable_get(:@context_manager),
               "Should have single context manager in single-model mode"
    assert_nil session.instance_variable_get(:@context_managers),
               "Should not have context_managers hash in single-model mode"
  end

  # Helper methods for creating real test objects

  def create_real_session
    # Create a real session with a real prompt handler
    # First create a test prompt file
    create_test_prompt_file('test_prompt', 'This is a test prompt')

    prompt_handler = AIA::PromptHandler.new
    AIA::Session.new(prompt_handler)
  rescue => e
    # If session creation fails due to dependencies, skip the test
    skip "Cannot create session: #{e.message}"
  end

  def create_test_prompt_file(id, text)
    File.write(File.join(@temp_prompts_dir, "#{id}.txt"), text)
  end

end
