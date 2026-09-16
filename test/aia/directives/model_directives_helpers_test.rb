# frozen_string_literal: true

# test/aia/directives/model_directives_helpers_test.rb
#
# Isolation tests for the pure helpers extracted from the show_*_models
# terminal reports.

require_relative '../../test_helper'
require 'ostruct'
require 'stringio'

class ModelDirectivesHelpersTest < Minitest::Test
  def setup
    @instance = AIA::ModelDirectives.new
  end

  # =========================================================================
  # entry_matches?
  # =========================================================================

  def test_entry_matches_with_no_terms
    assert @instance.send(:entry_matches?, '- ollama/llama3', [], [])
  end

  def test_entry_matches_requires_any_positive_term
    assert @instance.send(:entry_matches?, '- ollama/llama3', ['llama'], [])
    refute @instance.send(:entry_matches?, '- ollama/llama3', ['mistral'], [])
  end

  def test_entry_matches_rejects_negative_terms
    refute @instance.send(:entry_matches?, '- ollama/llama3', [], ['llama'])
    assert @instance.send(:entry_matches?, '- ollama/llama3', ['llama'], ['mistral'])
  end

  # =========================================================================
  # provider_model_entries
  # =========================================================================

  def test_provider_model_entries_prefixes_ids_with_slug
    provider = mock('provider')
    provider.stubs(:list_models).returns([OpenStruct.new(id: 'llama3')])
    AIA::ProviderRegistry.stubs(:instantiate).with('ollama').returns(provider)

    assert_equal ['- ollama/llama3'], @instance.send(:provider_model_entries, 'ollama')
  end

  # =========================================================================
  # rubyllm_header
  # =========================================================================

  def test_rubyllm_header_plain
    assert_equal "\nAvailable LLMs:", @instance.send(:rubyllm_header, [], [])
  end

  def test_rubyllm_header_with_terms
    header = @instance.send(:rubyllm_header, %w[gpt claude], ['ollama'])
    assert_equal "\nAvailable LLMs for gpt and claude (excluding: ollama):", header
  end

  # =========================================================================
  # print_filtered_entries
  # =========================================================================

  def test_print_filtered_entries_counts_and_prints_matches
    out = capture_stdout do
      @instance.send(:print_filtered_entries,
                     ['- a llama', '- a mistral'], ['llama'], [], 'model(s) available')
    end

    assert_includes out, '- a llama'
    refute_includes out, '- a mistral'
    assert_includes out, '1 model(s) available'
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
