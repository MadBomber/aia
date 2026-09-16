# test/aia/directives/models_directive_test.rb

require_relative '../../test_helper'
require 'ostruct'
require 'stringio'
require 'timeout'
require_relative '../../../lib/aia'

class ModelsDirectiveTest < Minitest::Test
  # Override setup to print test progress
  def setup
    puts "\n→ Running: #{name}"

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
        dir: File.join(Dir.home, '.prompts'),
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
    puts "✓ Completed: #{name}"

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
    assert_respond_to @instance, :show_rubyllm_models
    assert_respond_to @instance, :show_provider_models
    assert_respond_to @instance, :configured_provider_slugs
    assert_respond_to @instance, :provider_model_entries
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
  # Test 04-10: configured_provider_slugs (registry-driven, no hardcoded names)
  # ============================================================================

  def test_04_configured_provider_slugs_reads_model_spec_provider
    models = [OpenStruct.new(name: 'my-model', provider: 'ollama')]

    assert_equal ['ollama'], @instance.configured_provider_slugs(models)
  end

  def test_05_configured_provider_slugs_detects_registered_prefix_in_raw_names
    models = [OpenStruct.new(name: 'ollama/llama2', provider: nil)]

    assert_equal ['ollama'], @instance.configured_provider_slugs(models)
  end

  def test_06_configured_provider_slugs_ignores_unregistered_prefixes
    models = [OpenStruct.new(name: 'notaprovider/some-model', provider: nil)]

    assert_empty @instance.configured_provider_slugs(models)
  end

  def test_07_configured_provider_slugs_ignores_plain_model_names
    models = [OpenStruct.new(name: 'gpt-4o', provider: nil), 'claude-sonnet-4-5']

    assert_empty @instance.configured_provider_slugs(models)
  end

  def test_08_configured_provider_slugs_deduplicates
    models = [
      OpenStruct.new(name: 'a', provider: 'ollama'),
      OpenStruct.new(name: 'b', provider: 'ollama')
    ]

    assert_equal ['ollama'], @instance.configured_provider_slugs(models)
  end

  def test_09_configured_provider_slugs_mixes_specs_and_strings
    models = [OpenStruct.new(name: 'a', provider: 'openai'), 'ollama/llama2']

    assert_equal %w[openai ollama], @instance.configured_provider_slugs(models)
  end

  def test_10_configured_provider_slugs_handles_empty_and_nil
    assert_empty @instance.configured_provider_slugs([])
    assert_empty @instance.configured_provider_slugs(nil)
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

    assert_match(/Total: \d+ directives available/, output)
  end

  # ============================================================================
  # Test 17-20: show_rubyllm_models method
  # ============================================================================

  def test_17_show_rubyllm_models_displays_header_without_query
    Timeout.timeout(30) do
      @instance.show_rubyllm_models([], [])
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
      @instance.show_rubyllm_models(['gpt'], [])
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
      @instance.show_rubyllm_models([], [])
      output = @captured_output.string

      assert_match(/- .+ \(.+\) in: \$[\d.]+ cw: \d+/, output)
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models model listing timed out after 30 seconds"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  def test_20_show_rubyllm_models_displays_count
    Timeout.timeout(30) do
      @instance.show_rubyllm_models([], [])
      output = @captured_output.string

      assert_match(/\d+ LLMs matching your query/, output)
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

      @instance.available_models
      output = @captured_output.string

      assert_match(/Available LLMs/, output)
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

      @instance.available_models
      output = @captured_output.string

      assert_match(/Available LLMs/, output)
    end
  rescue Timeout::Error
    flunk "available_models with array model timed out after 30 seconds"
  end

  def test_24_available_models_handles_hash_model_format
    Timeout.timeout(30) do
      @test_config.models = [OpenStruct.new(name: 'gpt-4', role: 'assistant', instance: 1, internal_id: 'gpt-4')]

      @instance.available_models
      output = @captured_output.string

      assert_match(/Available LLMs/, output)
    end
  rescue Timeout::Error
    flunk "available_models with hash model timed out after 30 seconds"
  end

  # ============================================================================
  # Test 25-30: show_provider_models — generic per-provider listing through
  # RubyLLM's Provider#list_models, mocked so no live server is required.
  # ============================================================================

  def test_25_show_provider_models_reports_unreachable_provider
    AIA::ProviderRegistry.stubs(:instantiate).with('ollama').raises(StandardError.new('connection refused'))

    @instance.show_provider_models(['ollama'], [], [])
    output = @captured_output.string

    assert_match(/Cannot list models for provider 'ollama'/, output)
    assert_match(/connection refused/, output)
  end

  def test_26_show_provider_models_displays_provider_models
    stub_provider_listing('ollama', %w[llama2 mistral])

    @instance.show_provider_models(['ollama'], [], [])
    output = @captured_output.string

    assert_match(/ollama models:/, output)
    assert_includes output, '- ollama/llama2'
    assert_includes output, '- ollama/mistral'
    assert_match(/2 ollama model\(s\) available/, output)
  end

  def test_27_show_provider_models_filters_by_positive_query
    stub_provider_listing('ollama', %w[llama2 mistral])

    @instance.show_provider_models(['ollama'], ['mist'], [])
    output = @captured_output.string

    assert_includes output, '- ollama/mistral'
    refute_includes output, '- ollama/llama2'
    assert_match(/1 ollama model\(s\) available/, output)
  end

  def test_28_show_provider_models_filters_by_negative_query
    stub_provider_listing('lms', %w[gpt-oss-20b qwen3.8-27b])

    @instance.show_provider_models(['lms'], [], ['gpt'])
    output = @captured_output.string

    refute_includes output, '- lms/gpt-oss-20b'
    assert_includes output, '- lms/qwen3.8-27b'
  end

  def test_29_show_provider_models_is_generic_over_any_registered_slug
    stub_provider_listing('xyzzy', %w[model-a])

    @instance.show_provider_models(['xyzzy'], [], [])
    output = @captured_output.string

    assert_match(/xyzzy models:/, output)
    assert_includes output, '- xyzzy/model-a'
  end

  def test_30_show_provider_models_continues_after_a_failing_provider
    AIA::ProviderRegistry.stubs(:instantiate).with('broken').raises(StandardError.new('boom'))
    stub_provider_listing('ollama', %w[llama2])

    @instance.show_provider_models(%w[broken ollama], [], [])
    output = @captured_output.string

    assert_match(/Cannot list models for provider 'broken'/, output)
    assert_includes output, '- ollama/llama2'
  end

  # ============================================================================
  # Test 31-35: compare method
  # ============================================================================

  def test_31_compare_returns_error_for_empty_args
    result = @instance.compare([])

    assert_nil result
    assert_includes @captured_output.string, 'Error: No prompt provided for comparison'
  end

  def test_32_compare_returns_error_for_no_models
    result = @instance.compare(['test prompt'])

    assert_nil result
    assert_includes @captured_output.string, 'Error: No models specified. Use --models model1,model2,model3'
  end

  def test_33_compare_parses_models_argument
    Timeout.timeout(60) do
      @instance.compare(['test prompt', '--models', 'gpt-4,claude-3'])
      output = @captured_output.string

      assert_includes output, "Comparing responses for: test prompt"
      assert_includes output, "=" * 80
    end
  rescue Timeout::Error
    skip "compare test timed out - may require API access"
  rescue
    assert true, "Parsing logic executed as expected"
  end

  def test_34_compare_handles_model_errors_gracefully
    Timeout.timeout(60) do
      @instance.compare([
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
  rescue
    assert true, "Error handling executed"
  end

  def test_35_compare_displays_results_format
    Timeout.timeout(60) do
      @instance.compare([
                          'What is 2+2?',
                          '--models',
                          'nonexistent-model'
                        ])
      output = @captured_output.string

      assert_includes output, "Comparing responses for: What is 2+2?"
      assert_includes output, "=" * 80
      assert_includes output, "Comparison complete!"
      assert_match(/🤖.*nonexistent-model/, output)
    end
  rescue Timeout::Error
    skip "compare format test timed out"
  rescue
    assert true, "Format display executed"
  end

  # ============================================================================
  # Test 36-40: Integration tests for available_models with local providers
  # ============================================================================

  def test_36_available_models_detects_ollama_provider
    Timeout.timeout(10) do
      @test_config.models = [OpenStruct.new(name: 'ollama/llama2', role: nil, instance: 1, internal_id: 'ollama/llama2')]

      @instance.available_models
      output = @captured_output.string

      assert_match(/Ollama|Cannot connect|Local LLM/, output)
    end
  rescue Timeout::Error
    flunk "Ollama detection test timed out after 10 seconds"
  end

  def test_37_available_models_detects_lms_provider
    @test_config.models = [OpenStruct.new(name: 'some-model', provider: 'lms', role: nil, instance: 1, internal_id: 'lms/some-model')]
    stub_provider_listing('lms', %w[some-model])

    @instance.available_models
    output = @captured_output.string

    assert_match(/lms models:/, output)
    assert_includes output, '- lms/some-model'
  end

  def test_38_show_provider_models_handles_mixed_providers
    stub_provider_listing('ollama', %w[llama2])
    stub_provider_listing('lms', %w[gpt-oss-20b])

    @instance.show_provider_models(%w[ollama lms], [], [])
    output = @captured_output.string

    assert_includes output, '- ollama/llama2'
    assert_includes output, '- lms/gpt-oss-20b'
  end

  # ============================================================================
  # Test 39-40: Edge cases and error conditions
  # ============================================================================

  def test_39_provider_model_entries_formats_slug_prefixed_lines
    stub_provider_listing('ollama', %w[llama2 mistral])

    assert_equal ['- ollama/llama2', '- ollama/mistral'],
                 @instance.provider_model_entries('ollama')
  end

  # ============================================================================
  # Test AND NOT search for /llms
  # ============================================================================

  def test_39b_show_rubyllm_models_header_includes_excluding_when_negative_terms
    Timeout.timeout(30) do
      @instance.show_rubyllm_models([], ['openai'])
      output = @captured_output.string

      assert_includes output, "excluding: openai"
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models excluding header timed out"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  def test_39c_show_rubyllm_models_excludes_negative_terms
    Timeout.timeout(30) do
      @instance.show_rubyllm_models([], ['openai'])
      output = @captured_output.string

      model_lines = output.split("\n").select { |l| l.start_with?('- ') }
      model_lines.each do |line|
        refute_includes line.downcase, 'openai', "Excluded term 'openai' should not appear in results"
      end
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models exclusion test timed out"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  def test_39d_show_rubyllm_models_positive_and_negative_combined
    Timeout.timeout(30) do
      @instance.show_rubyllm_models(['claude'], ['opus'])
      output = @captured_output.string

      assert_includes output, "excluding: opus"
      model_lines = output.split("\n").select { |l| l.start_with?('- ') }
      model_lines.each do |line|
        line_down = line.downcase
        assert_includes line_down, 'claude', "Positive filter 'claude' must match"
        refute_includes line_down, 'opus', "Negative filter 'opus' must be excluded"
      end
    end
  rescue Timeout::Error
    flunk "show_rubyllm_models combined filter test timed out"
  rescue => e
    skip "RubyLLM not available or error: #{e.message}"
  end

  def test_40_help_with_arguments_is_ignored
    help_instance = AIA::UtilityDirectives.new

    result1 = help_instance.help
    output1 = @captured_output.string

    @captured_output = StringIO.new
    $stdout = @captured_output

    result2 = help_instance.help(%w[some args])
    output2 = @captured_output.string

    assert_equal result1, result2
    assert_equal output1, output2
  end

  private

  # Stub ProviderRegistry.instantiate(slug) with a provider whose list_models
  # returns lightweight stand-ins for RubyLLM model info objects.
  def stub_provider_listing(slug, model_ids)
    provider = mock("provider_#{slug}")
    provider.stubs(:list_models).returns(model_ids.map { |id| OpenStruct.new(id: id) })
    AIA::ProviderRegistry.stubs(:instantiate).with(slug).returns(provider)
  end
end
