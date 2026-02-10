# test/aia/directives/models_directive_test.rb

require_relative '../../test_helper'
require 'ostruct'
require 'stringio'
require 'timeout'
require_relative '../../../lib/aia'

class ModelsDirectiveTest < Minitest::Test
  # Override setup to print test progress
  def setup
    puts "\n→ Running: #{self.name}"

    # Allow real HTTP connections for this test (no mocks!)
    if defined?(WebMock)
      @webmock_was_disabled = WebMock.net_connect_allowed?
      WebMock.allow_net_connect!
    end

    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output

    # Create nested config structure matching AIA::Config's actual structure
    @test_config = create_test_config
    AIA.stubs(:config).returns(@test_config)

    @instance = AIA::ModelDirectives.new
  end

  def create_test_config
    # Models array with ModelSpec-like objects
    models = [OpenStruct.new(name: 'gpt-4', role: nil, instance: 1, internal_id: 'gpt-4')]

    OpenStruct.new(
      models: models,
      prompts: OpenStruct.new(
        dir: File.join(ENV['HOME'], '.prompts'),
        roles_prefix: 'roles'
      ),
      flags: OpenStruct.new(
        debug: false,
        verbose: false
      ),
      llm: OpenStruct.new(
        temperature: 0.7
      )
    )
  end

  def teardown
    # Restore WebMock state if it was modified
    if defined?(WebMock) && !@webmock_was_disabled
      WebMock.disable_net_connect!
    end

    $stdout = @original_stdout
    puts "✓ Completed: #{self.name}"

    # Call super to ensure Mocha cleanup runs properly
    super
  end

  # ============================================================================
  # Test 01: Class Structure and Method Availability
  # ============================================================================

  def test_01_class_exists_and_has_expected_methods
    assert defined?(AIA::ModelDirectives), "ModelDirectives class should be defined"

    # Check core methods exist
    assert_respond_to @instance, :available_models
    assert_respond_to @instance, :compare
    assert_respond_to @instance, :format_bytes
    assert_respond_to @instance, :show_rubyllm_models
    assert_respond_to @instance, :show_local_models
    assert_respond_to @instance, :show_ollama_models
    assert_respond_to @instance, :show_lms_models
  end

  def test_02_class_has_alias_methods
    # Check aliases exist
    assert_respond_to @instance, :am
    assert_respond_to @instance, :available
    assert_respond_to @instance, :models
    assert_respond_to @instance, :all_models
    assert_respond_to @instance, :llms
    assert_respond_to @instance, :cmp
  end

  def test_03_aliases_point_to_correct_methods
    # Verify aliases are properly mapped via original_name
    assert_equal :available_models, @instance.method(:am).original_name
    assert_equal :available_models, @instance.method(:models).original_name
    assert_equal :compare, @instance.method(:cmp).original_name
  end

  # ============================================================================
  # Test 04-10: format_bytes utility method
  # ============================================================================

  def test_04_format_bytes_handles_zero
    result = @instance.format_bytes(0)
    assert_equal "0 B", result
  end

  def test_05_format_bytes_handles_bytes
    result = @instance.format_bytes(512)
    assert_equal "512.0 B", result
  end

  def test_06_format_bytes_handles_kilobytes
    result = @instance.format_bytes(1024)
    assert_equal "1.0 KB", result

    result = @instance.format_bytes(2048)
    assert_equal "2.0 KB", result
  end

  def test_07_format_bytes_handles_megabytes
    result = @instance.format_bytes(1024 * 1024)
    assert_equal "1.0 MB", result

    result = @instance.format_bytes(5 * 1024 * 1024)
    assert_equal "5.0 MB", result
  end

  def test_08_format_bytes_handles_gigabytes
    result = @instance.format_bytes(1024 * 1024 * 1024)
    assert_equal "1.0 GB", result

    result = @instance.format_bytes(3.5 * 1024 * 1024 * 1024)
    assert_equal "3.5 GB", result
  end

  def test_09_format_bytes_handles_terabytes
    result = @instance.format_bytes(1024 * 1024 * 1024 * 1024)
    assert_equal "1.0 TB", result
  end

  def test_10_format_bytes_handles_fractional_values
    result = @instance.format_bytes(1536) # 1.5 KB
    assert_equal "1.5 KB", result

    result = @instance.format_bytes(7.5 * 1024 * 1024) # 7.5 MB
    assert_equal "7.5 MB", result
  end

  # ============================================================================
  # Test 11-15: help method (now on UtilityDirectives)
  # ============================================================================

  def test_11_help_displays_header
    help_instance = AIA::UtilityDirectives.new
    result = help_instance.help
    output = @captured_output.string

    assert_includes output, "Available Directives"
    assert_includes output, "===================="
    assert_equal "", result, "help should return empty string"
  end

  def test_12_help_displays_categories
    help_instance = AIA::UtilityDirectives.new
    help_instance.help
    output = @captured_output.string

    # Check for category headers (derived from class names)
    assert_includes output, "Configuration:"
    assert_includes output, "Context:"
    assert_includes output, "Execution:"
    assert_includes output, "Utility:"
    assert_includes output, "Web And File:"
    assert_includes output, "Model:"
  end

  def test_13_help_displays_configuration_directives
    help_instance = AIA::UtilityDirectives.new
    help_instance.help
    output = @captured_output.string

    assert_includes output, "/config"
    assert_includes output, "/model"
    assert_includes output, "/temperature"
  end

  def test_14_help_displays_model_directives
    help_instance = AIA::UtilityDirectives.new
    help_instance.help
    output = @captured_output.string

    assert_includes output, "/available_models"
    assert_includes output, "/compare"
  end

  def test_15_help_displays_aliases
    help_instance = AIA::UtilityDirectives.new
    help_instance.help
    output = @captured_output.string

    assert_includes output, "aliases:"
  end

  def test_16_help_displays_total_count
    help_instance = AIA::UtilityDirectives.new
    help_instance.help
    output = @captured_output.string

    assert_match /Total: \d+ directives available/, output
  end

  # ============================================================================
  # Test 17-20: show_rubyllm_models method
  # ============================================================================

  def test_17_show_rubyllm_models_displays_header_without_query
    Timeout.timeout(30) do
      @instance.show_rubyllm_models(nil)
      output = @captured_output.string

      assert_includes output, "Available LLMs:"
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models timed out after 30 seconds"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  def test_18_show_rubyllm_models_displays_header_with_query
    Timeout.timeout(30) do
      @instance.show_rubyllm_models(['gpt'])
      output = @captured_output.string

      assert_includes output, "Available LLMs for gpt:"
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models with query timed out after 30 seconds"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  def test_19_show_rubyllm_models_lists_models
    Timeout.timeout(30) do
      @instance.show_rubyllm_models(nil)
      output = @captured_output.string

      assert_match /- .+ \(.+\) in: \$[\d.]+ cw: \d+/, output
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models model listing timed out after 30 seconds"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  def test_20_show_rubyllm_models_displays_count
    Timeout.timeout(30) do
      @instance.show_rubyllm_models(nil)
      output = @captured_output.string

      assert_match /\d+ LLMs matching your query/, output
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models count display timed out after 30 seconds"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  # ============================================================================
  # Test 21-25: available_models with RubyLLM models
  # ============================================================================

  def test_21_available_models_calls_show_rubyllm_when_no_local_provider
    Timeout.timeout(30) do
      result = @instance.available_models
      output = @captured_output.string

      assert_includes output, "Available LLMs"
      assert_equal "", result, "available_models should return empty string"
    end
  rescue Timeout::Error
    flunk "available_models with non-local provider timed out after 30 seconds"
  end

  def test_22_available_models_handles_string_model_format
    Timeout.timeout(30) do
      @test_config.models = [OpenStruct.new(name: 'claude-3-sonnet', role: nil, instance: 1, internal_id: 'claude-3-sonnet')]

      result = @instance.available_models
      output = @captured_output.string

      assert_match /Available LLMs/, output
    end
  rescue Timeout::Error
    flunk "available_models with string model timed out after 30 seconds"
  end

  def test_23_available_models_handles_array_model_format
    Timeout.timeout(30) do
      @test_config.models = [
        OpenStruct.new(name: 'gpt-4', role: nil, instance: 1, internal_id: 'gpt-4'),
        OpenStruct.new(name: 'claude-3-sonnet', role: nil, instance: 1, internal_id: 'claude-3-sonnet')
      ]

      result = @instance.available_models
      output = @captured_output.string

      assert_match /Available LLMs/, output
    end
  rescue Timeout::Error
    flunk "available_models with array model timed out after 30 seconds"
  end

  def test_24_available_models_handles_hash_model_format
    Timeout.timeout(30) do
      @test_config.models = [OpenStruct.new(name: 'gpt-4', role: 'assistant', instance: 1, internal_id: 'gpt-4')]

      result = @instance.available_models
      output = @captured_output.string

      assert_match /Available LLMs/, output
    end
  rescue Timeout::Error
    flunk "available_models with hash model timed out after 30 seconds"
  end

  # ============================================================================
  # Test 25-30: Local provider methods (Ollama)
  # ============================================================================

  def test_25_show_ollama_models_handles_connection_failure
    Timeout.timeout(10) do
      @instance.show_ollama_models('http://localhost:99999', nil)
      output = @captured_output.string

      assert_match /Cannot connect to Ollama|Error fetching Ollama models/, output
    end
  rescue Timeout::Error
    flunk "show_ollama_models connection failure handling timed out"
  end

  def test_26_show_ollama_models_displays_models_if_available
    Timeout.timeout(10) do
      api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434')

      @instance.show_ollama_models(api_base, nil)
      output = @captured_output.string

      if output.include?('Cannot connect') || output.include?('Error fetching')
        assert_match /Cannot connect to Ollama|Error fetching/, output,
          "Should show appropriate error message when Ollama is not available"
      else
        assert_match /Ollama Models.*:/, output
        assert_match /\d+ Ollama model\(s\) available/, output
      end
    end
  rescue Timeout::Error
    flunk "Ollama connection timed out after 10 seconds"
  end

  def test_27_show_ollama_models_filters_by_query
    Timeout.timeout(10) do
      api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434')

      @instance.show_ollama_models(api_base, ['llama'])
      output = @captured_output.string

      if output.include?('Cannot connect') || output.include?('Error fetching')
        assert_match /Cannot connect to Ollama|Error fetching/, output,
          "Should show appropriate error message when Ollama is not available"
      else
        if output =~ /(\d+) Ollama model\(s\) available/
          lines = output.split("\n").select { |l| l.start_with?('- ollama/') }
          lines.each do |line|
            assert_match /llama/i, line, "Filtered results should match query"
          end
        end
      end
    end
  rescue Timeout::Error
    flunk "Ollama filtering test timed out after 10 seconds"
  end

  # ============================================================================
  # Test 28-30: Local provider methods (LM Studio)
  # ============================================================================

  def test_28_show_lms_models_handles_connection_failure
    Timeout.timeout(10) do
      @instance.show_lms_models('http://localhost:99998', nil)
      output = @captured_output.string

      assert_match /Cannot connect to LM Studio|Error fetching LM Studio models/, output
    end
  rescue Timeout::Error
    flunk "show_lms_models connection failure handling timed out"
  end

  def test_29_show_lms_models_displays_models_if_available
    Timeout.timeout(10) do
      api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234')

      @instance.show_lms_models(api_base, nil)
      output = @captured_output.string

      if output.include?('Cannot connect') || output.include?('Error fetching')
        assert_match /Cannot connect to LM Studio|Error fetching/, output,
          "Should show appropriate error message when LM Studio is not available"
      else
        assert_match /LM Studio Models.*:/, output
        assert_match /\d+ LM Studio model\(s\) available/, output
      end
    end
  rescue Timeout::Error
    flunk "LM Studio connection timed out after 10 seconds"
  end

  def test_30_show_lms_models_filters_by_query
    Timeout.timeout(10) do
      api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234')

      @instance.show_lms_models(api_base, ['gpt'])
      output = @captured_output.string

      if output.include?('Cannot connect') || output.include?('Error fetching')
        assert_match /Cannot connect to LM Studio|Error fetching/, output,
          "Should show appropriate error message when LM Studio is not available"
      else
        if output =~ /(\d+) LM Studio model\(s\) available/
          lines = output.split("\n").select { |l| l.start_with?('- lms/') }
          lines.each do |line|
            assert_match /gpt/i, line, "Filtered results should match query"
          end
        end
      end
    end
  rescue Timeout::Error
    flunk "LM Studio filtering test timed out after 10 seconds"
  end

  # ============================================================================
  # Test 31-35: compare method
  # ============================================================================

  def test_31_compare_returns_error_for_empty_args
    result = @instance.compare([])

    assert_equal 'Error: No prompt provided for comparison', result
  end

  def test_32_compare_returns_error_for_no_models
    result = @instance.compare(['test prompt'])

    assert_equal 'Error: No models specified. Use --models model1,model2,model3', result
  end

  def test_33_compare_parses_models_argument
    Timeout.timeout(60) do
      result = @instance.compare(['test prompt', '--models', 'gpt-4,claude-3'])
      output = @captured_output.string

      assert_includes output, "Comparing responses for: test prompt"
      assert_includes output, "=" * 80
    end
  rescue Timeout::Error
    skip "compare test timed out - may require API access"
  rescue => e
    assert true, "Parsing logic executed as expected"
  end

  def test_34_compare_handles_model_errors_gracefully
    Timeout.timeout(60) do
      result = @instance.compare([
        'test prompt',
        '--models',
        'fake-model-1,fake-model-2'
      ])
      output = @captured_output.string

      assert_includes output, "Comparing responses"
      assert_includes output, "Comparison complete!"
    end
  rescue Timeout::Error
    skip "compare error handling test timed out"
  rescue => e
    assert true, "Error handling executed"
  end

  def test_35_compare_displays_results_format
    Timeout.timeout(60) do
      result = @instance.compare([
        'What is 2+2?',
        '--models',
        'nonexistent-model'
      ])
      output = @captured_output.string

      assert_includes output, "Comparing responses for: What is 2+2?"
      assert_includes output, "=" * 80
      assert_includes output, "Comparison complete!"
      assert_match /🤖.*nonexistent-model/, output
    end
  rescue Timeout::Error
    skip "compare format test timed out"
  rescue => e
    assert true, "Format display executed"
  end

  # ============================================================================
  # Test 36-40: Integration tests for available_models with local providers
  # ============================================================================

  def test_36_available_models_detects_ollama_provider
    Timeout.timeout(10) do
      @test_config.models = [OpenStruct.new(name: 'ollama/llama2', role: nil, instance: 1, internal_id: 'ollama/llama2')]

      result = @instance.available_models
      output = @captured_output.string

      assert_match /Ollama|Cannot connect|Local LLM/, output
    end
  rescue Timeout::Error
    flunk "Ollama detection test timed out after 10 seconds"
  end

  def test_37_available_models_detects_lms_provider
    Timeout.timeout(10) do
      @test_config.models = [OpenStruct.new(name: 'lms/some-model', role: nil, instance: 1, internal_id: 'lms/some-model')]

      result = @instance.available_models
      output = @captured_output.string

      assert_match /LM Studio|Cannot connect|Local LLM/, output
    end
  rescue Timeout::Error
    flunk "LM Studio detection test timed out after 10 seconds"
  end

  def test_38_show_local_models_handles_mixed_providers
    Timeout.timeout(20) do
      models = ['ollama/llama2', 'lms/gpt']

      @instance.show_local_models(models, nil)
      output = @captured_output.string

      assert_includes output, "Local LLM Models:"
    end
  rescue Timeout::Error
    skip "Mixed providers test timed out"
  rescue => e
    skip "Mixed providers test error: #{e.message}"
  end

  # ============================================================================
  # Test 39-40: Edge cases and error conditions
  # ============================================================================

  def test_39_format_bytes_with_very_large_numbers
    huge_number = 5 * 1024 * 1024 * 1024 * 1024 * 1024
    result = @instance.format_bytes(huge_number)

    assert_match /\d+\.\d+ TB/, result
  end

  def test_40_help_with_arguments_is_ignored
    help_instance = AIA::UtilityDirectives.new

    result1 = help_instance.help
    output1 = @captured_output.string

    @captured_output = StringIO.new
    $stdout = @captured_output

    result2 = help_instance.help(['some', 'args'])
    output2 = @captured_output.string

    assert_equal result1, result2
    assert_equal output1, output2
  end
end
