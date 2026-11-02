# frozen_string_literal: true

# test/aia/provider_registry_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ProviderRegistryTest < Minitest::Test
  def test_slugs_returns_registered_provider_slugs_as_strings
    slugs = AIA::ProviderRegistry.slugs

    assert_kind_of Array, slugs
    assert_includes slugs, 'openai'
    assert_includes slugs, 'anthropic'
    assert slugs.all?(String)
  end

  def test_registered_for_builtin_provider
    assert AIA::ProviderRegistry.registered?('openai')
    assert AIA::ProviderRegistry.registered?(:anthropic)
  end

  def test_registered_is_false_for_unknown_and_nil
    refute AIA::ProviderRegistry.registered?('notaprovider')
    refute AIA::ProviderRegistry.registered?(nil)
  end

  def test_available_is_true_for_registered_provider
    assert AIA::ProviderRegistry.available?('openai')
  end

  def test_available_is_false_for_unloadable_slug
    refute AIA::ProviderRegistry.available?('notaprovider')
  end

  def test_load_rejects_slugs_with_unsafe_characters
    refute AIA::ProviderRegistry.load('../etc/passwd')
    refute AIA::ProviderRegistry.load('Not-A-Slug')
    refute AIA::ProviderRegistry.load('')
  end

  def test_load_registers_conventional_provider_gem_on_demand
    skip 'ruby_llm-providers-lms gem not in this bundle' unless AIA::ProviderRegistry.load('lms')

    assert AIA::ProviderRegistry.registered?('lms')
  end

  def test_instantiate_raises_for_unknown_provider
    assert_raises(RubyLLM::Error) { AIA::ProviderRegistry.instantiate('notaprovider') }
  end

  def test_apply_env_endpoints_sets_base_from_env_for_registered_provider
    original = RubyLLM.config.ollama_api_base
    original_env = ENV.fetch('OLLAMA_API_BASE', nil)
    ENV['OLLAMA_API_BASE'] = 'http://env.test:11434/v1'

    AIA::ProviderRegistry.apply_env_endpoints

    assert_equal 'http://env.test:11434/v1', RubyLLM.config.ollama_api_base
  ensure
    ENV['OLLAMA_API_BASE'] = original_env
    RubyLLM.config.ollama_api_base = original
  end

  def test_apply_env_endpoints_defaults_ollama_when_unset
    original = RubyLLM.config.ollama_api_base
    original_env = ENV.fetch('OLLAMA_API_BASE', nil)
    ENV.delete('OLLAMA_API_BASE')

    AIA::ProviderRegistry.apply_env_endpoints

    if original.nil?
      assert_equal "http://localhost:11434/v1", RubyLLM.config.ollama_api_base
    else
      assert_equal original, RubyLLM.config.ollama_api_base
    end
  ensure
    ENV['OLLAMA_API_BASE'] = original_env
    RubyLLM.config.ollama_api_base = original
  end
end
